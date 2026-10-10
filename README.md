# Lukearch

Lukearch is a small **Arch-based, unofficial** Linux distribution project built with `archiso`.

## Project goals

- Keep the first iteration maintainable and reproducible.
- Build and test a minimal x86_64 live ISO profile.
- Plan a realistic path to ARM and Apple silicon support without overstating current capabilities.

## Current status

- ✅ x86_64 `archiso` profile under `/profile`. The ISO builds and boots under
  UEFI in QEMU to the Plasma desktop; it has not been tested on hardware yet.
- ✅ Build, QEMU, and VirtualBox test scripts are included under `/scripts`.
- ✅ The live image provides a lightweight KDE Plasma desktop started by SDDM.
- ✅ The live environment targets systems with 4 GB of RAM, with zram enabled
  for additional memory headroom.
- ✅ The live image uses a non-root desktop account with password-protected
  sudo administration and default-deny inbound firewall rules.
- ✅ Keyboard and mouse input use generic libinput drivers, while GPU-specific
  drivers remain optional.
- ✅ ARM64 profile under `/profile-aarch64`. The ISO builds on an ARM64 Linux host
  and boots to the Plasma desktop in VirtualBox on Apple silicon.
- ⚠️ Booting directly on Apple silicon hardware (outside a VM) is not supported.
- ✅ Guided installer, `lukearch-install`, on both images. It installs to a disk
  with the recommended settings, and every setting can be changed or loaded
  from a settings file. See [Installing to a disk](#installing-to-a-disk).

## Repository layout

- `profile/` - archiso profile (x86_64)
  - `profiledef.sh` - profile metadata and build settings
  - `packages.x86_64` - live environment package list
  - `pacman.conf` - repository config for profile builds
  - `airootfs/` - files copied into live root filesystem
- `scripts/build-iso.sh` - builds the x86_64 ISO with `mkarchiso`
- `scripts/test-iso.sh` - boots an ISO in QEMU for local testing
- `scripts/test-virtualbox.sh` - boots the ARM64 ISO in VirtualBox
- `profile-aarch64/` - ARM64 archiso profile for Apple M-series testing
- `profile/airootfs/root/customize_airootfs.sh` - enables KDE display and network services
- `profile/airootfs/etc/nftables.conf` - default-deny inbound firewall policy
- `profile/airootfs/etc/sddm.conf.d/autologin.conf` - locked live-session account
- `profile/airootfs/etc/sudoers.d/lukearch` - power-user sudo, which requires the separate administrator password
- `profile/airootfs/usr/local/sbin/lukearch-set-admin-password` - one-time setup for the administrator password
- `profile/airootfs/usr/local/bin/lukearch-install` - guided installer and settings-file installer (identical in both profiles)
- `profile/airootfs/usr/share/lukearch/install-packages` - packages installed onto the target system
- `profile/packages.x86_64` - generic input and baseline graphics packages
- `docs/arm-support.md` - ARM/Apple-silicon status and roadmap
- `DEV_HIST.md` - dated development history and validation notes
- `STRUCTURE.md` - visual map of the repository, build flow, and auth model
- `scripts/update-structure.sh` - regenerates the file tree in `STRUCTURE.md`; CI fails if it is stale

## Development history

Every repository change must update both this file and
[`DEV_HIST.md`](DEV_HIST.md). macOS `.DS_Store` files are ignored. The CI workflow enforces this requirement for
commits and pull requests.
Each push must include both files, because the check compares each push on its own.

## Build instructions (x86_64 host)

Install dependencies on Arch Linux:

```bash
sudo pacman -S --needed archiso qemu-desktop
```

Build the ISO:

```bash
./scripts/build-iso.sh
```

Optional directory overrides:

```bash
WORK_DIR="$PWD/work" OUT_DIR="$PWD/out" ./scripts/build-iso.sh
```

`mkarchiso` requires root privileges; the script uses `sudo` automatically if needed.

Build on a case-sensitive filesystem. Packages such as `xorg-server` ship
paths that differ only by case (for example `usr/lib/Xorg.wrap` and
`usr/lib/xorg/`). On macOS's default case-insensitive APFS volume, or any
case-insensitive mount, the build fails with "not overwriting dir with file".
Use a Linux filesystem or a case-sensitive volume for `WORK_DIR`.
`build-iso.sh` checks this before building and stops with an error otherwise.

Both profiles set `DisableDownloadTimeout` in their `pacman.conf`, so slow
mirrors don't abort the package download. pacstrap may ask to confirm the
installation; answer `Y`, or pipe `yes |` into the script when running it
unattended.

## Security notes

The live image is designed to be safer by default on older hardware:

- KDE starts as the unprivileged `lukearch` account. The account is initially
  locked, so set its password from a terminal with `sudo passwd lukearch`.
  That password is for logging in; it does not authorize sudo.
- Members of `wheel`, including `lukearch`, administer the device through sudo.
  Sudo asks for a separate administrator password, which is the root password.
  Set it once with `sudo lukearch-set-admin-password`. That command asks for the
  login password first, then refuses to run once the administrator password
  exists, so the login password cannot replace it later.
- The administrator password also works for root console login. `su` is limited
  to members of `wheel` through `pam_wheel`. The root account stays locked until
  that one-time setup runs.
- The one exception is `sudo passwd lukearch`, which `lukearch` can run without
  a password. The sudoers rule is not limited to first run; it only lets the
  account change its own login password.
- SSH is not installed. The enabled services are NetworkManager, SDDM, nftables,
  Bluetooth, and the desktop session. CUPS starts on demand through `cups.socket`
  and listens only on localhost.
- nftables blocks unsolicited inbound traffic while allowing established
  connections, DHCP, and ICMP/ICMPv6 needed for normal networking.
- The live filesystem is ephemeral. It is not a substitute for an installed,
  encrypted system, and physical access to a running computer can still expose
  the active session.

For a persistent installation, enable automatic or regular security updates,
use full-disk encryption where practical, and avoid reusing credentials from
other systems.

## Installing to a disk

The live session has an **Install Lukearch** entry in the application menu. It
runs `sudo lukearch-install` in a terminal. Sudo asks for the administrator
password, so set it first with `sudo lukearch-set-admin-password` if you have
not already.

The guided installer starts with the recommended settings selected. Choose
**Install with these settings** to use them as they are, or change any item
first:

| Setting | Recommended | Other choices |
| --- | --- | --- |
| Disk | Erase a whole disk and create a 1 GiB EFI partition plus a root partition | Use existing partitions (dual boot): keep the EFI partition, format one root partition |
| Root filesystem | ext4 | btrfs with `@` and `@home` subvolumes, zstd compression |
| Encryption | None | LUKS2 on the root partition, with a passphrase at boot |
| Swap | zram (compressed RAM swap) | None |
| Timezone | Australia/Sydney | Any name from `/usr/share/zoneinfo` |
| Language | en_US.UTF-8 | Any UTF-8 locale |
| Keyboard layout | us | Any console keymap |
| Hostname | lukearch | Any valid hostname |
| Username | lukearch | Any valid name (not `root`) |
| Sudo password | Administrator (root) password | The user's own password |
| Desktop session | Plasma on X11 on ARM, Plasma on Wayland on x86_64 | The other Plasma session |
| Autologin | Off | On |
| Extra packages | None | Any packages from the repositories |

The installer always asks for the passwords when it runs. It never stores them.
Passwords must be at least 8 characters. Before anything is erased, it shows a
summary and asks you to confirm.

The installer will not offer the disk it is running from, or the disk that holds
the live medium, so it cannot erase the system it runs on.

### Settings files for power users

Power users can keep the settings in a file:

```bash
lukearch-install --print-config > install.conf   # the recommended settings
nano install.conf                                # change what you need
sudo lukearch-install --config install.conf --dry-run   # check the file; changes nothing
sudo lukearch-install --config install.conf             # install, asking for passwords
```

Each line is `KEY=value`. Unknown keys are rejected. Set `CONFIRM_ERASE=yes` to
skip the typed `ERASE` confirmation for unattended runs. Passwords are read from
standard input when it is not a terminal, so a script can pipe them in. The
installer also saves the settings it used to `/root/lukearch-install.conf` on the
installed system, without the passwords.

The installed system uses systemd-boot. The installer writes the boot entry and
the systemd-boot update service is enabled, so boot-loader updates are applied
automatically. Kernel options are fixed by the installer; the kernel package can
be changed with `KERNEL=` (for example `linux-lts`).

Tested: the ARM64 path was installed to a blank disk in a VirtualBox VM with the
recommended settings. The installed disk booted from its own EFI partition to
the SDDM login screen and then to the Plasma X11 desktop. Not yet tested:
encryption (LUKS2), btrfs, the existing-partitions mode, the guided menus under
a terminal session, and the x86_64 installer on hardware.

Limitations:

- UEFI firmware only. BIOS systems are not supported.
- Secure Boot is not configured.
- The installer does not resize existing partitions. Use existing partitions
  mode with unused space that you have already prepared.
- The installer does not set up RAID, LVM, or swap partitions.
- Progress and errors are written to `/var/log/lukearch-install.log` on the live
  system.

## Hardware drivers

Lukearch uses generic `libinput` and `xf86-input-libinput` drivers for
keyboards and mice, avoiding device-specific input drivers. `mesa` supplies
the baseline open graphics userspace without locking the image to one GPU
vendor.

No vendor-specific GPU driver is bundled or blocked. On an installed system,
power users can install the driver appropriate to their hardware, for example:

```bash
# AMD open drivers
sudo pacman -S mesa vulkan-radeon

# Intel open drivers
sudo pacman -S mesa vulkan-intel

# NVIDIA proprietary driver
sudo pacman -S nvidia
```

The exact package depends on the GPU and kernel in use. These commands change
the running live session only unless the system has a persistent installation;
the live filesystem is discarded at reboot.

## Live image features

Both live images include the KDE Plasma desktop, Firefox, Kate, and these
tools:

- **Removable media:** `udisks2` automounting, plus `exfatprogs`, `ntfs-3g`,
  `btrfs-progs`, and `dosfstools` for common USB and disk formats.
- **Bluetooth:** `bluez`, `bluez-utils`, and Plasma's `bluedevil` applet, with
  `bluetooth.service` enabled.
- **Printing:** CUPS with `print-manager`, with `cups.service` enabled.
- **Power and sensors:** `power-profiles-daemon`, `lm_sensors`, and `fwupd`.
- **Locale:** `en_US.UTF-8`, with the timezone set to Australia/Sydney. Change
  `/etc/localtime` and `/etc/locale.conf` in the profile's `airootfs/` if you
  need different defaults.

The x86_64 image also includes `intel-media-driver` for Intel video
acceleration and `vulkan-intel` and `vulkan-nouveau` for the Vulkan drivers.

These features are installed and enabled in the images, but Bluetooth, printing,
and removable media have not been tested on hardware yet.

## Apple silicon and VirtualBox

Apple M1 and newer Macs require an ARM64 guest for native VirtualBox
virtualization. Install VirtualBox 7.2 or newer.

1. On an ARM64 Linux build host (for example, an ARM64 Linux VM or separate
   ARM64 machine), build the ARM64 profile:

   ```bash
   ARCH=aarch64 ./scripts/build-iso.sh
   ```

2. Copy the resulting `lukearch-aarch64*.iso` to the Mac.
3. On the Mac, create and start the test VM:

   ```bash
   ./scripts/test-virtualbox.sh /absolute/path/to/lukearch-aarch64.iso
   ```

The test script creates an ARM platform VM with the `armv8virtual` chipset, UEFI
firmware, the `qemuramfb` display, NAT networking, and the ISO on a SATA DVD
drive. It uses a USB tablet pointer and USB keyboard, because ARM guests have no
PS/2 controller, so the mouse does not work with PS/2 settings. It refuses to run
on non-ARM64 hosts.

If a VM with the same name already exists (`Lukearch ARM64` by default), the
script stops. Set `REPLACE_VM=1` to delete that VM and its disks first, or set
`VM_NAME` to create another. Set `START_TYPE=headless` to start without a
window.

The ARM64 profile uses standard UEFI and is intended for VirtualBox ARM64
guests. The existing x86_64 profile remains the image for Intel and AMD PCs.
VirtualBox on Apple silicon cannot natively run the x86_64 Lukearch ISO.
The ARM64 ISO builds inside an ARM64 Arch Linux ARM VM. In VirtualBox it boots
to the `lukearch` autologin and a Plasma desktop. VirtualBox's ARM guest has no
DRM device, so the live session runs on X11 (Xorg with the framebuffer driver)
rather than Wayland.
The VirtualBox VM setup has been checked with `VBoxManage` 7.2.20.

The ARM64 ISO is a hybrid image with an EFI system partition, so it also boots
as a disk. Convert it to a VirtualBox disk with
`VBoxManage convertfromraw <iso> <vdi> --format VDI`, attach the disk to a VM
with the settings above, and export the VM as an OVA. An OVA holds the disk and
VM settings, not the ISO file. Changes made in the live session are lost on
reboot.

## Test in QEMU

After building, run:

```bash
./scripts/test-iso.sh
```

Or provide an explicit ISO path:

```bash
./scripts/test-iso.sh /absolute/path/to/lukearch.iso
```

Without a path, the script picks the newest `*-x86_64.iso` in `out/`. It refuses
an aarch64 ISO, because `out/` can hold both.

The script boots through UEFI when it finds OVMF firmware (`edk2-ovmf` on Arch
Linux, or Homebrew's QEMU on macOS), matching the systemd-boot path on modern
PCs. Set `FIRMWARE=bios` to test the syslinux BIOS path instead. Pass extra QEMU
options with `QEMU_EXTRA_ARGS`, for example `QEMU_EXTRA_ARGS="-display none"`.

The test boots the KDE Plasma live path with 4096 MB of guest RAM by default.
This is the supported low-memory path: it does not copy the compressed
filesystem into RAM, and the live system enables a zram swap device sized to
half of detected RAM. Override the test size when needed:

```bash
MEMORY_MB=4096 ./scripts/test-iso.sh
```

Avoid selecting the `copytoram` boot entry on a 4 GB system unless the ISO is
small enough to leave room for KDE Plasma and running applications; that mode
intentionally uses additional RAM for the complete live filesystem.

On non-x86_64 hosts, this script runs x86_64 emulation and prints a reminder that it does not validate native ARM boot support.

## ARM and Apple silicon notes

The ARM64 image targets ARM64 machines with UEFI firmware, and is tested in
VirtualBox on Apple silicon. It does not boot directly on Apple silicon hardware,
which needs the Asahi Linux boot path. The x86_64 ISO cannot run natively on Apple
silicon.

See [`docs/arm-support.md`](docs/arm-support.md) for details.

## Milestones

Done:

- x86_64 and ARM64 live images that build and boot to the Plasma desktop
  (x86_64 in QEMU, ARM64 in VirtualBox).
- Guided installer with recommended settings and a settings file for power
  users (`lukearch-install`).

Next:

1. Test the x86_64 image on hardware, starting with the Alienware M14x
   (NVIDIA/Optimus, Wi-Fi, Bluetooth, audio).
2. Add automated boot tests and release checks to CI.
3. Add Secure Boot support to the installer.
4. Migrate `customize_airootfs.sh` to declarative airootfs files before archiso
   removes support for it.
