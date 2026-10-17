# Development History

This file records user-facing, operational, and architectural changes to
Lukearch. Add a new dated entry for every repository change, and update
`README.md` when the change affects usage, support, build behavior, or project
status.

## 2026-10-17

### Installer blockers on the live ISO: keyring, mirrors, and an install test

A project review found that every installer test so far ran on the ARM64 build
VM, an ordinary Arch Linux ARM system, never from a booted live ISO. Two
problems only show up on the live ISO, because mkarchiso installs the image's
packages with `pacstrap -G -M`: no pacman keyring and no copy of the build
host's mirrorlist.

- **No pacman keyring.** pacman checks package signatures against the running
  system's keyring (`/etc/pacman.d/gnupg`), even when pacstrap installs into
  `/mnt`. The live images had none, so pacstrap would have failed. On ARM64
  that happens after the disk is erased, because the pre-install check only
  resolved package names. Both profiles now ship and enable
  `pacman-init.service`, which runs `pacman-key --init` and
  `pacman-key --populate` at boot, like the official archiso profile. Each boot
  gets its own local signing key.
- **No x86_64 mirrors.** The x86_64 live image had the stock
  `pacman-mirrorlist` file, with every server commented out, so the installer's
  pre-install check would have stopped with "The package mirrors cannot be
  reached", and installed systems would have copied the empty list. The x86_64
  profile now ships `etc/pacman.d/mirrorlist` with Arch's `geo` and `fastly`
  mirrors; pacstrap copies it to the installed system. ARM64 is unaffected: Arch
  Linux ARM's mirrorlist enables `mirror.archlinuxarm.org`.
- **Pre-install check.** `lukearch-install` now refuses to start, before it asks
  for passwords or changes a disk, when the keyring holds none of the
  distribution master keys listed in `/usr/share/pacman/keyrings/*-trusted`.
  Checked with a stub `pacman-key`: no keyring and a keyring with only the local
  key are refused; a populated keyring passes.
- **Install test in CI.** New `scripts/test-install.sh`, run by a new
  `install-test` job in `build-iso.yml` after the ISO build. It boots the ISO's
  kernel in QEMU with UEFI (OVMF) and `systemd.run=`, which runs
  `scripts/test-install-guest.sh` (passed in through QEMU's fw_cfg) instead of
  the desktop. That script checks that `pacman-init.service` is enabled, that
  the keyring and mirrorlist are usable, installs onto a blank 24 GB disk with
  the recommended settings, and checks the installed mirrorlist, keyring, and
  boot entry. The host then boots the installed disk without the ISO and waits
  for SDDM and the `lukearch login:` prompt on the serial port. The serial logs
  are uploaded as an artifact.
- `validate-project.yml` checks the new files, that both profiles enable
  `pacman-init.service`, and that the x86_64 mirrorlist has a server.
- **CI run 4 (commit `4a90578`) stopped at the build.** Packages were installed
  with `pacstrap`, and `plasma-x11-session` was not found (see the next bullet).
  The install test never ran.
- **CI run 5 (commit `0ba1a7a`).** The ISO built and uploaded. The install test
  ran the installer and it refused to start, so nothing was installed. The
  installer's first environment check requires UEFI (`/sys/firmware/efi`), but
  the test booted the kernel with `-kernel`, which skips the firmware. The test
  now boots the ISO's own EFI image, which holds systemd-boot, the kernel, and
  its initramfs. The test copies that image, replaces its boot entry so it adds
  `systemd.run=` and the serial console, and boots that copy first
  (`bootindex=0`). The changed boot entry was checked on a synthetic FAT image,
  and the test has not yet run in CI.
- **CI run 6 (commit `949746e`).** The ISO built. The install test stopped
  before QEMU started: the script looked for a file named `efiboot.img`, and this
  archiso version's image has another name. The script now finds the image by
  its contents, an `.img` file in the ISO that has `EFI/BOOT/BOOTX64.EFI`, and
  prints the ISO's `.img` files if none matches. The discovery was checked on a
  fake ISO.
- **CI run 7 (commit `dd326f6`).** The ISO built. The install test found no
  `.img` file with `EFI/BOOT/BOOTX64.EFI`: the ISO's only `.img` is the
  initramfs. archiso writes its EFI system image as a partition of the ISO, not
  as a file in it, so `bsdtar` cannot see it. The script now reads the ISO's
  partition table with `sfdisk`, copies the EFI system partition (MBR type `ef`
  or GPT type `C12A7328`) out with `dd`, and checks it for
  `EFI/BOOT/BOOTX64.EFI`. The extraction was checked on synthetic MBR and GPT
  disks.
- **CI run 8 (commit `b4277f3`).** The EFI partition was copied, the guest
  booted, and the installer ran. It then failed on `wipefs: /dev/vda: failed to
  erase vfat magic string ... Operation not permitted`. The guest had hardcoded
  `DISK=/dev/vda`, but the host attaches the read-only EFI image first, so
  `/dev/vda` was the EFI image. The guest now picks the first writable disk
  that is not zram. The installer refused nothing else; the keyring service
  ran at boot.
- **x86_64 build broke on a renamed package.** The first CI run of this branch
  failed in pacstrap with `target not found: plasma-x11-session`: the package
  is no longer in the Arch repositories. The x86_64 package lists no longer
  name it. The x86_64 image and installs use the Wayland Plasma session, and
  the installer rejects the X11 choice on x86_64 (it has no session file there).
  The ARM64 profile still uses the package and needs its own check, because its
  repository is different.
- **x86_64 install aborted in pacstrap on PackageKit.** The next run got through
  the disk and the packages, then stopped: the PackageKit pacman hook printed
  `GDBus.Error ... The name is not activatable`, and pacstrap failed. D-Bus is
  not running in the install chroot. The x86_64 installed system now uses
  Flatpak for Discover, as ARM64 already did. The package lists drop
  `packagekit-qt6` and `archlinux-appstream-data`, and CI checks both profiles
  for this. The change was not run in CI when this entry was written.

## 2026-10-12

### First CI ISO build

- `build-iso.yml` ran for the first time on pull request #5 and passed. It
  built `lukearch-2026.10.11-x86_64.iso` (2,155,544,576 bytes, SHA-256
  `067d3db3318713f10145529007b1b1ffa26aaa291b80e269188756062f342be1`) in
  13 minutes and uploaded it as the `lukearch-x86_64-iso` artifact.
- The ISO built in CI has not been booted.

## 2026-10-11

### Review fixes: installer, launcher, boot menu, and CI

Installer (`lukearch-install`):

- **Failures did not stop the install.** `run_install` was called as
  `run_install || exit 1` and `run_install || true`, and bash ignores `set -e`
  in a function called from a condition. A failed `mount` would have let
  pacstrap install into the live system's `/mnt`, and a failed step could still
  end with "Installation complete". Validation is now `prepare_install`, and
  `install_system` runs as a plain statement after it succeeds. Tested by making
  `mkfs.ext4` fail: the install stopped, reported the failure, and left nothing
  mounted.
- **Password prompts looped forever when input ended.** `read_secret` returned
  success with an empty value at end of input, so a script that piped too few
  lines spun on "must be at least 8 characters". It now fails with "No more
  input".
- **Checks before erasing.** Before asking for passwords, the installer refuses
  a target that is mounted, used as swap, or open as an encrypted, LVM, or RAID
  volume. In existing-partitions mode it requires free space on the EFI
  partition: 100 MiB on x86_64 and 300 MiB on ARM64 (an ARM64 install used
  207 MiB, mostly device trees and `Image.gz`). It resolves every package against a temporary copy of the package
  databases, which checks the network and catches misspelled extra packages
  before the disk is touched. The temporary folder is made readable, because
  pacman 7 downloads as the `alpm` user.
- **Confirmation defaults to No** in the guided installer, so pressing Enter no
  longer erases the disk.
- **autodetect restored.** The earlier note that `arch-chroot` does not provide
  `/sys` was wrong: `arch-chroot` mounts `/sys`, and `findmnt -T /` reports the
  target's filesystem. `lsinitcpio` had shown no `ahci`, `sd_mod`, or `ext4`
  modules because `linux-aarch64` builds them in. The hooks are now Arch's
  default order, including `autodetect`.
- **No fallback initramfs.** Only the default image is built, which halves the
  initramfs space used on the EFI partition.
- **Login screen.** SDDM's state file now preselects the chosen session and
  user, so a manual login on ARM does not land on the Wayland session.
- **Pick lists.** Timezone (region, then city), language, and keyboard layout
  are chosen from lists built from `timedatectl list-timezones`,
  `/usr/share/i18n/SUPPORTED`, and `localectl list-keymaps`, the same sources
  the validation uses. Each falls back to typing when its list is unavailable.
- **Existing-partitions reinstall failed.** Installing onto existing partitions
  with an EFI partition that already held an earlier install's kernel files
  failed: pacman refused to replace `Image`, `dtbs/`, and the initramfs
  ("exists in filesystem"). In existing-partitions mode pacstrap now runs with
  `--overwrite 'boot/*'` (with an alternate root, pacman matches the pattern
  against paths without the leading `/`; `/boot/*` matched nothing), and the
  plan says the earlier kernel and boot files
  are replaced. Other files on the EFI partition, such as Windows Boot Manager,
  are left alone.
- **Menus hid choices.** dialog's automatic list height showed a single row of
  the two-item disk menu, hiding "existing partitions". Menus now pass an
  explicit height that fits the terminal.
- A "Checking the disk, the network, and the packages" message shows while the
  pre-install checks run; before, the screen was blank for several seconds.
- Partitions are wiped of old signatures (`--wipe-partitions always` in wipe
  mode, `wipefs` on the root partition in existing-partitions mode), and an
  empty UUID stops the install instead of writing a broken boot entry.
- The installed system's `pacman.conf` sets `DisableDownloadTimeout`. Without
  it, installing a package on the installed ARM64 system failed with "Operation
  too slow" from `mirror.archlinuxarm.org`.

Discover on ARM64:

- On the installed ARM64 system, Discover showed KDE's warning that PackageKit
  support for Arch Linux ARM is incomplete, recommending removal of
  `packagekit-qt6` and Flatpak instead. The ARM64 list now installs `flatpak`
  (whose package ships the Flathub remote) instead of `packagekit-qt6`. After the
  swap, Discover listed Flathub applications with icons and no warning. x86_64
  keeps PackageKit.
- Discover's "No detected devices" error in a VM comes from the fwupd backend
  and is harmless.
- pacstrap's "Refreshing PackageKit" hook fails in the chroot ("The name is not
  activatable"), because D-Bus is not running there. pacstrap continues and
  the install is unaffected.

Tests on the ARM64 builder (VirtualBox):

- Preflight: a missing package, a mounted target, and input that ends before
  the passwords each stopped the installer before the disk was changed.
- Forced failure: with `mkfs.ext4` replaced by a failing stub, the installer
  stopped at that step, reported the failure, and left nothing mounted.
- btrfs with LUKS2: installed, then booted in a separate VM. The `autodetect`
  initramfs (16.5 MB, with `dm-crypt`) asked for the passphrase, SDDM
  preselected Plasma (X11) and the user, and login reached the desktop. The
  seat rule was copied from the live files, and only the default initramfs
  exists.
- Existing partitions: kept an EFI partition holding the earlier install and a
  stand-in Windows Boot Manager file, and installed onto the old LUKS root
  partition with a small package list. The first run failed on the kernel file
  conflicts (fixed above). After the fix the install completed: the root was
  wiped and formatted as ext4, the Windows file was unchanged, and the disk
  booted to the graphical target with SDDM running.
- Guided menus, driven in `tmux` with the screen captured at each step: the
  timezone region and city lists (Australia and Sydney preselected), the keymap
  and locale lists, both disk modes, the disk list (only the scratch disk, not
  the builder's system disk), the checking message, the four password prompts,
  and the summary. Pressing Enter at the summary returned to the menu and left
  the disk unchanged. Quit printed "No changes were made."

Live image:

- **Desktop launcher.** The icon ran `konsole -e sudo lukearch-install`. On a
  fresh live session sudo asked for a root password that did not exist, and the
  window closed at once, hiding the error. It now runs
  `lukearch-install-launcher`, which sets the `lukearch` and administrator
  passwords when needed, starts the installer, and keeps the window open.
- `lukearch-set-admin-password --status` prints whether the root and `lukearch`
  passwords are set. Sudoers allows exactly that command without a password.
- **BIOS boot menu.** Added `systemd.firstboot=off` to match the UEFI entries,
  and a Memtest86+ entry. archiso 91 never copies the EFI build of Memtest86+
  (it compares the uppercase `X64` architecture name with `x64`), so
  `memtest86+-efi` was removed from the x86_64 package list.
- Removed the x86_64 `NetworkManager.service` wants-symlink, which duplicated
  `systemctl enable` in `customize_airootfs.sh`.
- Updated the motd on both images and the out-of-date notes in
  `docs/arm-support.md` and `scripts/build-iso.sh`.
- The ARM64 mirror has no working HTTPS (its certificate does not match), so it
  stays on HTTP. The README's security notes now explain what that exposes.

CI:

- shellcheck now lints every shell script, not only the installer. Small fixes
  in `build-iso.sh`, `test-iso.sh`, and the profiledef files.
- New step: files both profiles share must be identical. `nftables.conf`
  differed only in blank lines and is now the same in both.
- New step: runs the installer's `--print-config` and `--dry-run` with sample
  settings files, and checks that missing disks, unknown keys, and invalid
  values are rejected.
- New workflow `build-iso.yml` builds the x86_64 ISO in a privileged Arch Linux
  container (the same way it was built locally) on pull requests and pushes to
  `main` that touch the x86_64 profile or build script, or by hand. It uploads
  the ISO and its checksum as an artifact kept for 7 days. Its first run is
  recorded under 2026-10-12.

### Discover on installed systems

- Added KDE's Discover app store and the PackageKit backend (`packagekit-qt6`)
  to the installed-system package list in both profiles. The x86_64 list also
  adds `archlinux-appstream-data` for application names and descriptions.
- Discover asks for the user's password through polkit. The sudo administrator
  password is not used for this.
- CI checks that both installed-system lists include Discover.
- Not yet verified: whether Discover finds updates and installs through the
  pacman backend on a booted installed system, and whether ARM64 repositories
  carry `archlinux-appstream-data`, which the ARM64 list does not add.

### Installer desktop icon

- The live image now places the **Install Lukearch** launcher on the
  `lukearch` user's desktop, as well as in the application menu. Both profiles
  copy it in `customize_airootfs.sh` and mark it executable so Plasma offers it
  as a launcher.
- CI checks that the desktop copy is set up in both profiles.
- Not yet verified on a booted live image: the icon's appearance and whether
  Plasma asks for trust on first launch.

### Guided installer

- Added `lukearch-install` to both live profiles. The script is identical in both
  (CI checks this). It runs as a dialog menu, or from a settings file with
  `--config`.
- Recommended settings are the defaults: erase a whole disk, ext4, no
  encryption, zram swap, Australia/Sydney, en_US.UTF-8, US keyboard, hostname
  `lukearch`, sudo asks for the administrator (root) password, Plasma (Wayland
  on x86_64, X11 on ARM), no autologin.
- Power users can change every setting in the menu, or run `--print-config`,
  edit the file, check it with `--dry-run`, and install with `--config`. Unknown
  keys are rejected. Passwords are never stored: they are read from the
  terminal, or from stdin when a script pipes them in.
- Other options: existing partitions (dual boot, keeping the EFI partition),
  btrfs with `@` and `@home` subvolumes, LUKS2 root encryption, `KERNEL=`, and
  extra packages.
- Safety: the installer never offers the disk it runs from or the live medium,
  including through LUKS or LVM. It shows the plan and requires a typed `ERASE`
  unless `CONFIRM_ERASE=yes`.
- The installed system gets the live system's `su` PAM policy, nftables rules,
  zram config, and os-release. The installer also writes the systemd-boot entry,
  the initramfs, and the sudoers rule for the chosen admin password.
- Live packages: added `arch-install-scripts`, `dialog`, `cryptsetup`, and the
  keyring for each architecture (`archlinux-keyring` on x86_64,
  `archlinuxarm-keyring` on ARM64). Added the target package list at
  `usr/share/lukearch/install-packages` and a desktop entry that runs the
  installer in a terminal.
- CI: lints the installer with shellcheck, checks that both copies match, and
  checks the required files, package lists, and key installer features.

### Installer test: btrfs with LUKS2 on ARM64

- Ran the installer on the ARM64 builder with `FILESYSTEM=btrfs` and
  `ENCRYPT=yes`. The install completed. The target has `@` and `@home`
  subvolumes, the `sd-encrypt` hook, and a boot entry with `rd.luks.name` and
  `rootflags=subvol=@`. The passphrase unlocks the volume.
- Booted the encrypted disk in VirtualBox. The passphrase prompt accepted the
  typed passphrase, and the system reached the graphical target with SDDM
  started. The display stayed on the boot log because this disk did not have the
  `master-of-seat` udev rule; the rule is copied only from a live image, as in
  the earlier test.
- Installer run time was dominated by pacstrap downloads, which slowed to a
  crawl for about an hour near the end of the transfer.

### Installer CI fix

- CI's shellcheck flagged `A && B || C` constructs in the installer's menu
  handlers. Rewrote them as `if` blocks; behavior is unchanged.
- README now notes the installer lint and the profile-copy check.

### Installer test on ARM64

- Ran the installer on the ARM64 builder VM against a blank 24 GB disk with the
  recommended settings. The install completed. The safety check refused the
  builder's own system disk.
- Booting the installed disk in a new VirtualBox VM reached the SDDM login
  screen (Plasma X11 preselected). Logging in reached the Plasma desktop.
- Found and fixed two problems during the test:
  - `autodetect` added no modules to the target's initramfs, because it reads
    `/sys`, which `arch-chroot` does not provide. The installer now omits
    `autodetect`, so the image includes the storage drivers.
  - The ARM64 keyring was not populated on the target. The installer now runs
    `pacman-key --populate` for `archlinux` and `archlinuxarm` when the keyring
    exists.
- The installed disk had no display until it had the `master-of-seat` udev
  rule. The builder is not a live image, so the installer had no rule to copy.
  The installer copies the rule when the live image has it. The rebuilt ARM64
  ISO contains the rule, the installer, the package list, and the ARM64
  keyring (checked in the squashfs). The installed-from-live boot is not yet
  tested.
- The test also surfaced two non-issues: the duplicated lines in the output file
  were a display artifact (the log has one "Installation complete" line), and the
  sddm default session on the login screen follows its own rules.
- Not tested: LUKS2 encryption, btrfs, the existing-partitions mode, the dialog
  menus in a terminal, the x86_64 installer, and BIOS systems (not supported).

## 2026-10-10

### ARM64 VirtualBox pointer and keyboard fixed

- The ARM64 VM used PS/2 pointer and keyboard devices, which the ARM guest does
  not have. The guest never received pointer input, so the mouse did not work.
  The exported OVA carried the same settings.
- Set `--mouse usbtablet --keyboard usb --usb-xhci on` in the test script and the
  exported OVA. Verified: the guest detects a VirtualBox USB tablet and USB
  keyboard, and Xorg registers the tablet as a pointer.
- Not verified: pointer movement in the VirtualBox GUI window. Headless
  `controlvm` input did not reach the guest, so this needs a GUI check on the Mac.
- Added a CI check for the USB pointer setting. The check uses a plain pattern,
  because the first version left the CI run without any steps.

### Project review fixes

Verified by building both ISOs with the repo's own `build-iso.sh` (ARM64 in an
Arch Linux ARM VM, x86_64 in an emulated Arch container), booting them through
the updated test scripts, and inspecting the built images.

- **VirtualBox script** (`test-virtualbox.sh`): uses a SATA DVD drive, the
  `qemuramfb` display, and NAT, matching the verified VM. It no longer deletes an
  existing VM unless `REPLACE_VM=1`, and accepts `START_TYPE`. Verified: the
  script boots the ARM64 ISO to the Plasma desktop, and a second run stops
  instead of replacing the VM.
- **QEMU script** (`test-iso.sh`): picks only `*-x86_64.iso`, refuses aarch64
  ISOs, and boots through UEFI when OVMF is present (Arch `edk2-ovmf` or
  Homebrew), falling back to BIOS. Adds `FIRMWARE` and `QEMU_EXTRA_ARGS`.
  Verified: it boots the x86_64 ISO under UEFI to the Plasma desktop.
- **x86_64 X11 fallback:** added `plasma-x11-session`; Wayland stays the default
  session.
- **Failed boot unit:** masked `systemd-loop@.service` in both profiles. It tried
  to attach the boot CD to a loop device and failed. Verified: the failure no
  longer appears in the x86_64 boot log.
- **Build robustness:** `build-iso.sh` stops early on a case-insensitive
  `WORK_DIR`. Both `pacman.conf` files set `DisableDownloadTimeout`. Confirmed
  that mkinitcpio's autodetect failure is already fixed by the profiles'
  `archiso.conf`, which leaves out the `autodetect` hook; both builds succeeded
  without the earlier bind-mount workaround.
- **ARM64 branding:** added `os-release` and `motd`, so the image identifies as
  Lukearch.
- **su:** limited to `wheel` with `pam_wheel`. Root console login still accepts
  the administrator password.
- **sudoers:** removed the redundant `Defaults:lukearch !targetpw`.
- **CUPS:** enabled `cups.socket` instead of `cups.service`, so CUPS starts on
  demand.
- **Docs:** README status, security notes, build and test instructions, ARM
  notes, and milestones updated; `docs/arm-support.md` rewritten for the current
  ARM64 state.
- **CI:** the required-files list includes the newer airootfs files.
- Verified in the built images: the `pam_wheel` rule, the sudoers change, the
  Lukearch `os-release`, the `systemd-loop` mask, `cups.socket`, and the Plasma
  X11 session are present in both ISOs.
- Not changed: `customize_airootfs.sh` is still used. It works in archiso 91, and
  migrating needs declarative user files and another way to rename the ARM64
  kernel, so it is left as a separate change.
- Not done: deleting the merged `fix/admin-sudo-and-arm-vbox` and
  `copilot/setup-initial-lukearch-repository` branches. The permission system
  blocked it.
- Not verified at runtime: `su` restriction and CUPS socket activation, because
  the live images have no SSH.

### CI tree check fixed

- A macOS `.DS_Store` file had been committed in the USB pointer change. It is
  removed and ignored. The regenerated `STRUCTURE.md` tree is now current, so
  the tree check passes.
- The CI runs were starting again after the workflow was re-enabled.

### Push check documented

- Added a README note that the documentation check compares each push on its
  own, so each push must include both README.md and DEV_HIST.md.

### README documents ARM64 disk boot and OVA export

- Added the steps to README: the ARM64 ISO is a hybrid image, so it can be
  converted to a VirtualBox disk and booted, then exported as an OVA. Verified:
  the disk-boot VM reached the Plasma desktop, and the exported OVA imports with
  the expected settings.

### CI check matches the current ARM64 boot mode

- The ARM64 CI check still looked for `uefi-aa64.systemd-boot.esp`, the boot mode
  replaced earlier with `uefi.systemd-boot`. The check now looks for the current
  name, so the validation job passes again.

### x86_64 builds and boots; live feature set added

- Built the x86_64 ISO for the first time, in an emulated Arch container on the
  M4 Pro. Two profile bugs surfaced and were fixed:
  - `airootfs_image_tool_options` used `comp`; mksquashfs needs `-comp`.
  - The releng archiso mkinitcpio config included PXE hooks, which need
    `nbd-client` and `nfsmount`. The config is now trimmed to the hooks this
    image uses.
- Verified in QEMU (UEFI, emulated): the x86_64 ISO boots to the Plasma
  desktop, with Firefox in the taskbar and the new locale and timezone applied.
  Not verified on the M14x.
- Verified: the ARM64 repo ISO boots to the Plasma desktop in VirtualBox with
  the same feature set.
- Added to both live profiles: `udisks2`, `exfatprogs`, `ntfs-3g`,
  `btrfs-progs`, `dosfstools`; `bluez`, `bluez-utils`, `bluedevil`;
  `power-profiles-daemon`, `lm_sensors`, `fwupd`; `cups`, `print-manager`;
  `firefox`, `kate`.
- x86_64 only: `intel-media-driver`, `vulkan-intel`, `vulkan-nouveau`.
- Default locale `en_US.UTF-8`, timezone Australia/Sydney, and enabled
  `bluetooth.service` and `cups.service`. Both are set in the profile's
  `customize_airootfs.sh`.
- ARM64 hostname set to `lukearch-live`, matching the x86_64 profile.
- Not verified: Bluetooth, CUPS, removable media, and the NVIDIA and Optimus
  setup. The live images have no SSH, so service state was not checked.
- Not done: install to disk, Secure Boot, and automated boot tests in CI.

### Admin password flow verified on the booted ARM64 image; x86_64 boot fixes

- Ran the admin-password flow on a booted ARM64 live image over SSH (test-only
  build). The login password sets via `sudo passwd lukearch`; sudo rejects the
  login password before and after setup; the admin password authorizes sudo; the
  setup command refuses to run a second time. Root and the login account end
  locked and set as designed.
- Desktop options checked against the ARM64 repos: Plasma X11 (current, verified),
  XFCE (`xfce4-session`, `lightdm`; X11 only, lightest), labwc (Wayland
  compositor, needs DRM), GNOME (`gnome-shell`, Wayland-first), Cinnamon and MATE
  (X11). Plasma X11 stays as the default. XFCE is the fallback if the 4 GB RAM
  target or Plasma X11 causes trouble on the physical test hardware.
- Applied the same boot fixes to the x86_64 profile, which had the same gaps:
  - Added `mkinitcpio-archiso` and the releng `mkinitcpio.conf.d/archiso.conf`,
    so the initramfs includes the live-boot hooks.
  - Added `syslinux`, `memtest86+`, and `memtest86+-efi`. The BIOS boot mode
    requires `syslinux` in the package list.
  - Moved boot modes to `bios.syslinux` and `uefi.systemd-boot`, replacing the
    deprecated `uefi-x64` and `.mbr` names.
  - Added `systemd.firstboot=off` to both UEFI entries.
- Verified: mkarchiso's profile validation passes for the x86_64 profile. The
  full x86_64 ISO has not been built or booted, because the build host is ARM64.

### ARM64 live image reaches the Plasma desktop in VirtualBox

- Found why the desktop didn't start. VirtualBox's ARM guest exposes only an
  EFI framebuffer (`/dev/fb0`), with no DRM device. The ALARM kernel doesn't
  build `simpledrm`, so Wayland can't run. systemd-logind also reported the
  seat as not graphical, so SDDM never started a display.
- Changed the ARM64 profile:
  - Added `plasma-x11-session` and `xf86-video-fbdev`, so the live session can
    run on X11 over the framebuffer.
  - Set the autologin session to `plasmax11`.
  - Added `airootfs/etc/udev/rules.d/71-lukearch-framebuffer-seat.rules`, which
    tags the framebuffer `master-of-seat` so logind reports the seat as
    graphical.
- Verified: the unchanged repo ISO boots, autologs into the `lukearch` session,
  and shows the Plasma desktop in a VirtualBox screenshot.
- Verification used a separate test-only ISO with SSH and nftables disabled.
  It was built from a copy of the profile in a scratch directory, not the repo.
  It confirmed `kwin_x11` and `plasmashell` running as `lukearch`.
- Not verified: Wayland on hardware with a DRM driver, and any hardware beyond
  this VirtualBox guest.

### ARM64 ISO builds and boots in VirtualBox

- Built the ARM64 ISO inside an Arch Linux ARM VM running in VirtualBox on the
  M4 Pro Mac, using a real ext4 root filesystem. Docker's container overlay
  caused mkinitcpio's autodetect to fail.
- Fixed the ARM64 profile so the ISO boots:
  - `mkinitcpio-archiso` is in the package list, with a matching
    `airootfs/etc/mkinitcpio.conf.d/archiso.conf`, so the initramfs includes the
    archiso live-boot hooks.
  - The boot entry points at `initramfs-linux.img`, the name the ALARM preset
    produces.
  - `customize_airootfs.sh` copies the kernel to `vmlinuz-linux-aarch64`, the
    name archiso expects.
  - The boot entry adds `systemd.firstboot=off`, so the live image skips the
    timezone and locale wizard.
- Verified in VirtualBox (ARM platform, armv8virtual chipset, UEFI): the ISO
  boots through systemd-boot, the kernel, and systemd. NetworkManager comes up
  with the NIC link active, and SDDM starts and reaches "Graphical Interface".
- Not verified: the KDE desktop. The VirtualBox ARM console screenshots stop at
  the last boot-log line, and keyboard input isn't accepted by this guest, so
  login and the desktop couldn't be checked.
- Build-only workarounds (not in the repo): pacman download timeouts disabled
  in the build's copy of the profile; a bind mount on the chroot root for
  mkinitcpio autodetect; `/dev/fd` links restored in the VM.

### Build filesystem note

- Documented that builds must run on a case-sensitive filesystem. The ARM64
  build failed on a case-insensitive macOS mount because `xorg-server` ships
  paths that differ only by case. Confirmed by moving the work directory into
  the container, after which package installation completed.

### Repository structure guide

- Added `STRUCTURE.md`, a visual map of the repository with Mermaid diagrams for
  the profile-to-ISO flow, the build and test flow, and the sudo authentication
  model, plus a key-directories table.
- Added `scripts/update-structure.sh`, which regenerates the file tree in
  `STRUCTURE.md` from tracked files in the C locale so output is the same on
  every host.
- CI regenerates the tree and fails if `STRUCTURE.md` is out of date, so the
  tree stays current when files are added, moved, or removed. Diagrams and the
  key-directories table are still edited by hand.
- Linked `STRUCTURE.md` from the README repository layout.

### ARM64 boot mode fix

- Changed the ARM64 profile boot mode from `uefi-aa64.systemd-boot.esp` to
  `uefi.systemd-boot`. The old name is not accepted by archiso 91, which
  rejected the profile at validation. `uefi.systemd-boot` is the architecture-
  neutral mode that archiso maps to AA64 on ARM64.
- Verified by running `mkarchiso` for the aarch64 profile inside an ARM64 Arch
  Linux container on Apple silicon. The validation step now passes; full ISO
  build is pending.

### Separate administrator password for sudo

- Changed sudo for `wheel` members to ask for a separate administrator password
  (the root password) instead of the `lukearch` login password, using
  `Defaults:%wheel rootpw` in both x86_64 and ARM64 profiles.
- Added `lukearch-set-admin-password`, a one-time setup command. It asks for the
  login password once, then sets the root password. It refuses to run after root
  has a password, so the login password cannot replace the administrator
  password later. Its sudo exception is limited to that command.
- Tested with real sudo 1.9 in an Arch Linux container: the login password is
  rejected for sudo before and after setup; the administrator password works;
  the setup command refuses to run a second time; `sudo passwd root` with the
  login password is rejected; and the `sudo passwd lukearch` NOPASSWD rule still
  works.
- Consequence: the administrator password also allows `su` and root console
  login, because the root account is now unlocked after setup.
- Not yet tested: the same flow in a booted live image.

### Project review: ARM64 VirtualBox fix and documentation accuracy

- Checked the ARM64 VirtualBox smoke-test script against the local `VBoxManage`
  7.2.20 on an Apple silicon Mac. The previous `createvm` call created an x86
  platform VM (`piix3` chipset, Arch Linux 64-bit ostype), which cannot boot the
  aarch64 ISO.
- Changed `scripts/test-virtualbox.sh` to create the VM with
  `--platform-architecture arm`, set `--chipset armv8virtual`, and drop the x86
  `ArchLinux_64` ostype. The script now refuses to run on non-ARM64 hosts.
- Confirmed on temporary probe VMs (deleted afterward) that the ARM platform
  accepts `armv8virtual`, UEFI firmware, memory and CPU settings, and IDE, SATA,
  and NVMe storage controllers. Boot of the ARM64 ISO is not yet validated.
- Added CI guards that fail if the VirtualBox script regresses to the x86
  platform or the `ArchLinux_64` ostype.
- Corrected the README note on the `lukearch` sudoers rule. `sudo passwd
  lukearch` runs without a password for the life of the image, not only on first
  run. Behavior is unchanged.
- Clarified in the README which host runs each ARM64 build and test step, and
  that the VM setup has been checked with `VBoxManage` while ARM64 boot has not.
- Open items: the x86_64 and ARM64 ISO builds have not been run in this review.
  The x86_64 live initramfs may need the archiso mkinitcpio hook package to boot.
  This is unverified and was not changed.

### ARM64 and Apple silicon VirtualBox testing

- Added a separate `profile-aarch64/` using ARM64 UEFI boot configuration and
  Arch Linux ARM packages.
- Added architecture selection to the ISO build script.
- Added a VirtualBox ARM64 smoke-test script for VirtualBox 7.2+ on Apple
  M1-and-newer Macs.
- Documented the ARM64 Linux build-host requirement and the inability of
  Apple-silicon VirtualBox to natively boot the x86_64 profile.
- Retained the x86_64 profile for Intel and AMD PCs.
- Updated ARM support documentation and CI profile validation.

## 2026-10-10

### Generic input and optional GPU drivers

- Added generic libinput packages for keyboard and mouse compatibility.
- Added Mesa as baseline graphics userspace.
- Kept vendor-specific GPU drivers out of the image so power users can
  install the appropriate driver for their hardware.
- Documented the distinction between live-session package changes and
  persistent installation changes.

## 2026-10-10

### Power-user administration

- Restored sudo for administrative access without adding a default password.
- Added the `lukearch` account to the `wheel` group.
- Added a narrowly scoped first-run `sudo passwd lukearch` rule so the user
  can set a password from the live session.
- Normal sudo commands require that user-set password; the root account remains
  locked and SSH remains unavailable.

## 2026-10-10

### Security hardening for older hardware

- Added a locked, unprivileged `lukearch` desktop account and disabled root
  login credentials in the live image.
- Removed SSH from the live package set.
- Added nftables with a default-deny inbound policy that permits established
  traffic, DHCP, and ICMP/ICMPv6.
- Enabled nftables alongside NetworkManager and SDDM.
- Documented the security boundary between an ephemeral live image and a
  persistent encrypted installation.

## 2026-10-10

### KDE Plasma desktop

- Added a lightweight KDE Plasma package set for the x86_64 live image.
- Added SDDM, NetworkManager, PipeWire, and WirePlumber runtime support.
- Enabled SDDM and NetworkManager during the archiso root filesystem
  customization step.
- Documented KDE Plasma as the default graphical live environment while
  retaining the 4 GB RAM target.

## 2026-10-10

### 4 GB RAM target

- Removed the `archiso` build package from the live image package list.
- Added `zram-generator` with a zstd-backed swap device sized to half of
  detected RAM.
- Changed the default QEMU smoke-test memory to 4096 MB.
- Documented the low-memory boot path and the additional RAM cost of
  `copytoram`.
- Added CI validation for the low-memory profile settings.
- Added this development history and a CI rule requiring `README.md` and
  `DEV_HIST.md` updates with every repository change.
- ISO build and QEMU boot validation remain pending on a host with
  `mkarchiso` and `qemu-system-x86_64`.

## Before 2026-10-10

### Initial project skeleton

- Added the initial x86_64 `archiso` profile.
- Added build and QEMU smoke-test scripts.
- Added initial ARM and Apple silicon support planning documentation.
- Added project validation in GitHub Actions.
