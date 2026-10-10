# ARM and Apple Silicon Support Status

## Current status

Lukearch currently ships only an **x86_64 archiso profile** (`profile/`).
The provided build path (`scripts/build-iso.sh`) intentionally supports native x86_64 hosts only.

This means:

- The generated ISO is intended for x86_64 boot paths.
- It should not be treated as an Apple-silicon-native image.
- It is not yet a true aarch64 live image.

## Known limitations

- No `packages.aarch64` profile exists yet.
- No aarch64 kernel/initramfs artifacts are built in this repository yet.
- No ARM-specific bootloader configuration is implemented yet.
- Apple silicon has unique firmware/boot constraints and may require dedicated workflows (for example Asahi Linux-related paths).

## Practical testing right now

On ARM hosts (including Apple silicon), test the x86_64 ISO through virtualization/emulation:

- QEMU/UTM virtual machine running x86_64 guest mode.
- Confirm basic live environment behavior (boot menu, shell login, networking).

This validates project-level changes but does **not** validate native ARM boot.

## Candidate ARM targets for future work

1. Generic aarch64 UEFI hardware (servers/dev boards that support standard UEFI boot).
2. Virtualized aarch64 targets under QEMU/UTM for development iteration.
3. Apple silicon-specific path, likely separate from generic archiso assumptions.

## Work required for a true aarch64 image

1. Add a dedicated ARM profile (or architecture split) with `packages.aarch64`.
2. Ensure ARM kernel/initramfs generation and matching boot configuration.
3. Implement and test ARM bootloader paths appropriate to each target.
4. Validate in aarch64 VMs and on physical ARM hardware.
5. Document per-target installation and boot caveats (especially Apple silicon).

Until these steps are complete, Lukearch should be described as **x86_64-first with ARM planning in progress**.
