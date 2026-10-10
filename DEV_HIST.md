# Development History

This file records user-facing, operational, and architectural changes to
Lukearch. Add a new dated entry for every repository change, and update
`README.md` when the change affects usage, support, build behavior, or project
status.

## 2026-10-10

### Repository structure guide

- Added `STRUCTURE.md`, a visual map of the repository with Mermaid diagrams for
  the profile-to-ISO flow, the build and test flow, and the sudo authentication
  model, plus an annotated file tree.
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
