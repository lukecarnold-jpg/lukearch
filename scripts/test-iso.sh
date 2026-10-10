#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
OUT_DIR="${OUT_DIR:-$REPO_ROOT/out}"
ISO_PATH="${1:-}"

if [[ -z "$ISO_PATH" ]]; then
  # Only x86_64 images; out/ can also hold the aarch64 ISO, which this script cannot boot.
  ISO_PATH="$(ls -t "$OUT_DIR"/*-x86_64.iso 2>/dev/null | head -n1 || true)"
fi

if [[ -z "$ISO_PATH" ]]; then
  echo "No x86_64 ISO found. Provide a path or build first with scripts/build-iso.sh" >&2
  exit 1
fi

if [[ ! -f "$ISO_PATH" ]]; then
  echo "ISO file not found: $ISO_PATH" >&2
  exit 1
fi

case "$(basename "$ISO_PATH")" in
  *aarch64*)
    echo "This is an aarch64 ISO; test it with scripts/test-virtualbox.sh instead." >&2
    exit 1
    ;;
esac

if ! command -v qemu-system-x86_64 >/dev/null 2>&1; then
  echo "Missing required dependency: qemu-system-x86_64" >&2
  echo "Install on Arch Linux with: sudo pacman -S --needed qemu-desktop edk2-ovmf" >&2
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

MEMORY_MB="${MEMORY_MB:-4096}"
CPUS="${CPUS:-2}"
FIRMWARE="${FIRMWARE:-uefi}"

# UEFI is the default because it matches the systemd-boot path used on modern hardware.
FIRMWARE_ARGS=()
VARS_DIR=""
if [[ "$FIRMWARE" == "uefi" ]]; then
  OVMF_CODE=""
  for candidate in \
    /usr/share/edk2/x64/OVMF_CODE.4m.fd \
    /usr/share/edk2-ovmf/x64/OVMF_CODE.fd \
    /usr/share/OVMF/OVMF_CODE.fd \
    /opt/homebrew/share/qemu/edk2-x86_64-code.fd \
    /usr/local/share/qemu/edk2-x86_64-code.fd; do
    if [[ -f "$candidate" ]]; then
      OVMF_CODE="$candidate"
      break
    fi
  done

  if [[ -z "$OVMF_CODE" ]]; then
    echo "UEFI firmware (OVMF) not found; booting with BIOS instead." >&2
    echo "Install it on Arch Linux with: sudo pacman -S --needed edk2-ovmf" >&2
    FIRMWARE="bios"
  else
    VARS_DIR="$(mktemp -d)"
    trap 'rm -rf "$VARS_DIR"' EXIT
    OVMF_VARS_TEMPLATE="${OVMF_CODE/CODE/VARS}"
    if [[ "$OVMF_VARS_TEMPLATE" != "$OVMF_CODE" && -f "$OVMF_VARS_TEMPLATE" ]]; then
      cp "$OVMF_VARS_TEMPLATE" "$VARS_DIR/vars.fd"
    else
      # Homebrew ships no matching vars file; an empty store the same size as the code works.
      dd if=/dev/zero of="$VARS_DIR/vars.fd" bs="$(wc -c < "$OVMF_CODE" | tr -d ' ')" count=1 2>/dev/null
    fi
    FIRMWARE_ARGS=(
      -machine q35
      -drive "if=pflash,format=raw,readonly=on,file=$OVMF_CODE"
      -drive "if=pflash,format=raw,file=$VARS_DIR/vars.fd"
    )
  fi
fi

# Optional extra arguments, for example: QEMU_EXTRA_ARGS="-display none"
EXTRA_ARGS=()
if [[ -n "${QEMU_EXTRA_ARGS:-}" ]]; then
  read -r -a EXTRA_ARGS <<<"$QEMU_EXTRA_ARGS"
fi

echo "Booting $ISO_PATH with $FIRMWARE firmware." >&2
qemu-system-x86_64 \
  "${QEMU_ACCEL[@]}" \
  ${FIRMWARE_ARGS[@]+"${FIRMWARE_ARGS[@]}"} \
  -m "$MEMORY_MB" \
  -smp "$CPUS" \
  -boot d \
  -cdrom "$ISO_PATH" \
  -nic user,model=virtio-net-pci \
  ${EXTRA_ARGS[@]+"${EXTRA_ARGS[@]}"}
