# ARM and Apple Silicon Support Status

## Current status

Lukearch ships an x86_64 archiso profile (`profile/`) and a separate ARM64
profile (`profile-aarch64/`) for standard ARM64 UEFI guests.

This means:

- The generated ISO is intended for x86_64 boot paths.
- It should not be treated as an Apple-silicon-native image.
- It is not yet a true aarch64 live image.

## Known limitations

- The ARM64 profile uses Arch Linux ARM repositories and `linux-aarch64`.
- ARM64 builds must currently run on an ARM64 Linux build host.
- Apple silicon has unique firmware/boot constraints and may require dedicated workflows (for example Asahi Linux-related paths).

## Practical testing right now

On Apple silicon, use VirtualBox 7.2 or newer and test the ARM64 profile:

- Build `profile-aarch64` on an ARM64 Linux environment.
- Start the result with `scripts/test-virtualbox.sh`.
- Confirm KDE, input devices, networking, and sudo administration.

VirtualBox on Apple silicon cannot natively boot the x86_64 profile.

## Candidate ARM targets for future work

1. Generic aarch64 UEFI hardware (servers/dev boards that support standard UEFI boot).
2. Virtualized aarch64 targets under QEMU/UTM for development iteration.
3. Apple silicon-specific path, likely separate from generic archiso assumptions.

## Work required for a true aarch64 image

1. Validate ARM64 package availability and archiso compatibility in CI.
2. Validate ARM64 boot and KDE behavior in VirtualBox on M-series Macs.
3. Validate on generic aarch64 UEFI hardware.
4. Document per-target installation and boot caveats.

Lukearch remains **x86_64-first**, with ARM64 VirtualBox support in active
validation.
