# ARM and Apple Silicon Support Status

## Current status

Lukearch ships an x86_64 archiso profile (`profile/`) and a separate ARM64
profile (`profile-aarch64/`) for ARM64 machines with UEFI firmware.

- The ARM64 profile builds a live ISO from Arch Linux ARM packages and the
  `linux-aarch64` kernel.
- In VirtualBox 7.2 on Apple silicon, the ISO boots through systemd-boot to the
  `lukearch` autologin and a Plasma desktop.
- The ISO is a hybrid image with an EFI system partition, so it also boots when
  converted to a VirtualBox disk and exported as an OVA.
- `lukearch-install` installs the ARM64 system to a disk. The default
  (ext4, no encryption) was installed in VirtualBox and booted to the Plasma X11
  desktop from its own disk. Encryption and btrfs are not yet tested on ARM64.

## How the ARM64 image differs from x86_64

- **Desktop session:** VirtualBox's ARM guest exposes only an EFI framebuffer,
  and the ALARM kernel doesn't build `simpledrm`, so there is no DRM device and
  Wayland can't run. The image autologs into Plasma on X11 (`plasmax11`) using
  `xf86-video-fbdev`.
- **Seat rule:** a udev rule tags the framebuffer `master-of-seat`, so
  systemd-logind reports the seat as graphical and SDDM can start.
- **Kernel name:** `linux-aarch64` installs the kernel as `/boot/Image`;
  `customize_airootfs.sh` copies it to `vmlinuz-linux-aarch64`, the name archiso
  expects.
- **VirtualBox input:** the VM must use a USB tablet and USB keyboard, because
  ARM guests have no PS/2 controller.

## Building

- ARM64 builds must run on an ARM64 Linux host with a case-sensitive
  filesystem, such as an Arch Linux ARM VM. `scripts/build-iso.sh` refuses to
  cross-build.
- archiso is not in the Arch Linux ARM repositories. Install the
  architecture-independent `archiso` package from the Arch Linux repositories.

## Testing

On Apple silicon, use VirtualBox 7.2 or newer:

```bash
./scripts/test-virtualbox.sh /absolute/path/to/lukearch-aarch64.iso
```

VirtualBox on Apple silicon cannot boot the x86_64 profile.

## Known limitations

- Booting directly on Apple silicon hardware is not supported. That needs the
  Asahi Linux boot path, which archiso does not provide.
- Only VirtualBox has been tested. Generic ARM64 UEFI hardware is untested.
- Wayland has not been tested on ARM64 hardware with a DRM driver.
- Boards that boot without UEFI (Raspberry Pi firmware, U-Boot) need
  board-specific images and are out of scope.
