# Lukearch

Lukearch is a small **Arch-based, unofficial** Linux distribution project built with `archiso`.

## Project goals

- Keep the first iteration maintainable and reproducible.
- Build and test a minimal x86_64 live ISO profile.
- Plan a realistic path to ARM and Apple silicon support without overstating current capabilities.

## Current status

- ✅ Initial x86_64 `archiso` profile scaffold is present under `/profile`.
- ✅ Build and local QEMU test scripts are included under `/scripts`.
- ⚠️ Native ARM/aarch64 image support is **not implemented yet**.

## Repository layout

- `profile/` - archiso profile (x86_64)
  - `profiledef.sh` - profile metadata and build settings
  - `packages.x86_64` - live environment package list
  - `pacman.conf` - repository config for profile builds
  - `airootfs/` - files copied into live root filesystem
- `scripts/build-iso.sh` - builds the x86_64 ISO with `mkarchiso`
- `scripts/test-iso.sh` - boots an ISO in QEMU for local testing
- `docs/arm-support.md` - ARM/Apple-silicon status and roadmap

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

## Test in QEMU

After building, run:

```bash
./scripts/test-iso.sh
```

Or provide an explicit ISO path:

```bash
./scripts/test-iso.sh /absolute/path/to/lukearch.iso
```

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
