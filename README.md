# Lukearch

Lukearch is a small **Arch-based, unofficial** Linux distribution project built with `archiso`.

## Project goals

- Keep the first iteration maintainable and reproducible.
- Build and test a minimal x86_64 live ISO profile.
- Plan a realistic path to ARM and Apple silicon support without overstating current capabilities.

## Current status

- ✅ Initial x86_64 `archiso` profile scaffold is present under `/profile`.
- ✅ Build and local QEMU test scripts are included under `/scripts`.
- ✅ The live image provides a lightweight KDE Plasma desktop started by SDDM.
- ✅ The live environment targets systems with 4 GB of RAM, with zram enabled
  for additional memory headroom.
- ✅ The live image uses a non-root desktop account with password-protected
  sudo administration and default-deny inbound firewall rules.
- ✅ Keyboard and mouse input use generic libinput drivers, while GPU-specific
  drivers remain optional.
- ✅ A separate ARM64 profile is available for native Apple M-series
  virtualization.
- ⚠️ Native ARM/aarch64 image support is **not implemented yet**.

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
- `profile/packages.x86_64` - generic input and baseline graphics packages
- `docs/arm-support.md` - ARM/Apple-silicon status and roadmap
- `DEV_HIST.md` - dated development history and validation notes
- `STRUCTURE.md` - visual map of the repository, build flow, and auth model
- `scripts/update-structure.sh` - regenerates the file tree in `STRUCTURE.md`; CI fails if it is stale

## Development history

Every repository change must update both this file and
[`DEV_HIST.md`](DEV_HIST.md). The CI workflow enforces this requirement for
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
- The administrator password also works with `su` and root console login. The
  root account stays locked until that one-time setup runs.
- The one exception is `sudo passwd lukearch`, which `lukearch` can run without
  a password. The sudoers rule is not limited to first run; it only lets the
  account change its own login password.
- SSH is not installed, and only NetworkManager, SDDM, nftables, and the desktop
  session are enabled.
- nftables blocks unsolicited inbound traffic while allowing established
  connections, DHCP, and ICMP/ICMPv6 needed for normal networking.
- The live filesystem is ephemeral. It is not a substitute for an installed,
  encrypted system, and physical access to a running computer can still expose
  the active session.

For a persistent installation, enable automatic or regular security updates,
use full-disk encryption where practical, and avoid reusing credentials from
other systems.

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

The test script creates an ARM platform VM with the `armv8virtual` chipset and
UEFI firmware. It uses a USB tablet pointer and USB keyboard, because ARM guests
have no PS/2 controller, so the mouse does not work with PS/2 settings. It refuses to run on non-ARM64 hosts. It replaces any existing VM
named `Lukearch ARM64`, which is the default `VM_NAME`; override `VM_NAME` to keep
an existing VM.

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

Lukearch does **not** currently produce an Apple-silicon-native image.
A normal x86_64 `archiso` ISO should not be advertised as natively bootable on Apple silicon.

Practical near-term strategy:

1. Continue building/testing the x86_64 image (including via QEMU/UTM on Apple silicon).
2. Design a separate aarch64 image profile and boot path.
3. Validate on generic aarch64 UEFI hardware and Apple silicon-specific targets.

See [`docs/arm-support.md`](docs/arm-support.md) for details.

## Milestones

1. Keep x86_64 ISO builds reproducible and minimal.
2. Expand smoke tests and release checks.
3. Add an aarch64-capable profile and VM test path.
4. Explore Apple silicon-native boot strategy with clear support boundaries.
