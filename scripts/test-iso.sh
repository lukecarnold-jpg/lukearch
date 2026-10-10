#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
OUT_DIR="${OUT_DIR:-$REPO_ROOT/out}"
ISO_PATH="${1:-}"

if [[ -z "$ISO_PATH" ]]; then
  ISO_PATH="$(ls -t "$OUT_DIR"/*.iso 2>/dev/null | head -n1 || true)"
fi

if [[ -z "$ISO_PATH" ]]; then
  echo "No ISO found. Provide a path or build first with scripts/build-iso.sh" >&2
  exit 1
fi

if [[ ! -f "$ISO_PATH" ]]; then
  echo "ISO file not found: $ISO_PATH" >&2
  exit 1
fi

if ! command -v qemu-system-x86_64 >/dev/null 2>&1; then
  echo "Missing required dependency: qemu-system-x86_64" >&2
  echo "Install on Arch Linux with: sudo pacman -S --needed qemu-desktop" >&2
  exit 1
fi

HOST_ARCH="$(uname -m)"
if [[ "$HOST_ARCH" != "x86_64" ]]; then
  echo "Host architecture is $HOST_ARCH; testing will run x86_64 emulation." >&2
  echo "This does not validate native aarch64 boot behavior." >&2
fi

QEMU_ACCEL=("-accel" "tcg")
if [[ "$HOST_ARCH" == "x86_64" && -e /dev/kvm && -w /dev/kvm ]]; then
  QEMU_ACCEL=("-accel" "kvm")
fi

MEMORY_MB="${MEMORY_MB:-2048}"
CPUS="${CPUS:-2}"

exec qemu-system-x86_64 \
  "${QEMU_ACCEL[@]}" \
  -m "$MEMORY_MB" \
  -smp "$CPUS" \
  -boot d \
  -cdrom "$ISO_PATH" \
  -nic user,model=virtio-net-pci
