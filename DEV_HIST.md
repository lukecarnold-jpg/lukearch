# Development History

This file records user-facing, operational, and architectural changes to
Lukearch. Add a new dated entry for every repository change, and update
`README.md` when the change affects usage, support, build behavior, or project
status.

## 2026-10-10

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
