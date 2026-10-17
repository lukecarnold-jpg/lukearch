#!/usr/bin/env bash
# Tests the x86_64 installer from a booted live ISO, in QEMU with UEFI:
#
#   1. Boots the ISO's kernel with systemd.run=, which runs
#      scripts/test-install-guest.sh instead of the desktop. That script
#      installs onto a blank disk with the recommended settings.
#   2. Boots the installed disk on its own and waits for SDDM and a login
#      prompt on the serial port.
#
# CI runs this after building the ISO. It needs qemu-system-x86_64, qemu-img,
# OVMF, bsdtar, blkid, and mtools, plus KVM for a reasonable run time.
#
#   scripts/test-install.sh /path/to/lukearch-x86_64.iso
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GUEST_SCRIPT="$SCRIPT_DIR/test-install-guest.sh"
ISO_PATH="${1:-}"
DISK_SIZE="${DISK_SIZE:-24G}"
MEMORY_MB="${MEMORY_MB:-4096}"
CPUS="${CPUS:-2}"
INSTALL_TIMEOUT="${INSTALL_TIMEOUT:-3600}"
BOOT_TIMEOUT="${BOOT_TIMEOUT:-600}"
LOG_DIR="${LOG_DIR:-$PWD/test-install-logs}"

if [[ -z "$ISO_PATH" || ! -f "$ISO_PATH" ]]; then
  echo "Usage: $0 /path/to/lukearch-x86_64.iso" >&2
  exit 1
fi

for cmd in qemu-system-x86_64 qemu-img bsdtar blkid mcopy mmd mdir; do
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "Missing required command: $cmd" >&2
    exit 1
  fi
done

OVMF_CODE=""
for candidate in \
  /usr/share/edk2/x64/OVMF_CODE.4m.fd \
  /usr/share/OVMF/OVMF_CODE_4M.fd \
  /usr/share/OVMF/OVMF_CODE.fd \
  /usr/share/edk2-ovmf/x64/OVMF_CODE.fd; do
  if [[ -f "$candidate" && -f "${candidate/CODE/VARS}" ]]; then
    OVMF_CODE="$candidate"
    break
  fi
done
if [[ -z "$OVMF_CODE" ]]; then
  echo "UEFI firmware (OVMF) not found. The installer supports UEFI only." >&2
  exit 1
fi

ACCEL=(-accel tcg)
if [[ -e /dev/kvm && -w /dev/kvm ]]; then
  ACCEL=(-accel kvm -cpu host)
else
  echo "KVM is not available; the test runs under emulation and is slow." >&2
fi

label="$(blkid -s LABEL -o value "$ISO_PATH")"
if [[ -z "$label" ]]; then
  echo "Could not read the ISO's volume label: $ISO_PATH" >&2
  exit 1
fi

work="$(mktemp -d)"
qemu_pid=""
cleanup() {
  if [[ -n "$qemu_pid" ]]; then
    kill "$qemu_pid" 2>/dev/null || true
  fi
  rm -rf "$work"
}
trap cleanup EXIT

mkdir -p "$LOG_DIR"
cp "${OVMF_CODE/CODE/VARS}" "$work/vars.fd"
qemu-img create -f qcow2 "$work/disk.qcow2" "$DISK_SIZE" >/dev/null
bsdtar -xf "$ISO_PATH" -C "$work" arch/boot/x86_64/vmlinuz-linux arch/boot/x86_64/initramfs-linux.img

QEMU=(
  qemu-system-x86_64 -machine q35 "${ACCEL[@]}" -m "$MEMORY_MB" -smp "$CPUS"
  -drive "if=pflash,format=raw,readonly=on,file=$OVMF_CODE"
  -drive "if=pflash,format=raw,file=$work/vars.fd"
  -drive "file=$work/disk.qcow2,if=virtio,format=qcow2"
  -nic "user,model=virtio-net-pci"
  -display none -no-reboot
)

# Stage 1. The installer needs UEFI, so the firmware must start the live system
# itself. The ISO's EFI system image (efiboot.img) holds systemd-boot and the
# kernel. The test copies that image, replaces its boot entry with one that adds
# the serial console and systemd.run=, and boots that copy first (bootindex=0).
# The guest script reaches the guest through fw_cfg.
# The EFI system image is an .img file in the ISO with systemd-boot at
# EFI/BOOT/BOOTX64.EFI. Its name depends on the archiso version, so find it by
# its contents.
efi_name=""
while IFS= read -r candidate; do
  bsdtar -xf "$ISO_PATH" -C "$work" "$candidate" 2>/dev/null || continue
  if mdir -i "$work/$candidate" ::/EFI/BOOT/BOOTX64.EFI >/dev/null 2>&1; then
    efi_name="$candidate"
    break
  fi
  rm -f "$work/$candidate"
done < <(bsdtar -tf "$ISO_PATH" | grep -i -E '\.img$')
if [[ -z "$efi_name" ]]; then
  echo "The ISO has no EFI system image with EFI/BOOT/BOOTX64.EFI. Its .img files:" >&2
  bsdtar -tf "$ISO_PATH" | grep -i -E '\.img$' >&2 || echo "(none)" >&2
  exit 1
fi
efi_img="$work/$efi_name"
if ! mdir -i "$efi_img" ::/arch/boot/x86_64/vmlinuz-linux >/dev/null 2>&1; then
  echo "The EFI system image has no live kernel: $efi_name" >&2
  exit 1
fi

fw_cfg_name="opt/lukearch/test-install-guest.sh"
run="/usr/bin/sh -c 'modprobe qemu_fw_cfg && exec bash /sys/firmware/qemu_fw_cfg/by_name/$fw_cfg_name/raw'"
cat > "$work/loader.conf" <<'LOADER'
default lukearch-test.conf
timeout 0
LOADER
cat > "$work/lukearch-test.conf" <<ENTRY
title   Lukearch install test
linux   /arch/boot/x86_64/vmlinuz-linux
initrd  /arch/boot/x86_64/initramfs-linux.img
options archisobasedir=arch archisolabel=$label systemd.firstboot=off console=ttyS0 systemd.run="$run"
ENTRY
mmd -i "$efi_img" ::/loader 2>/dev/null || true
mmd -i "$efi_img" ::/loader/entries 2>/dev/null || true
mcopy -o -i "$efi_img" "$work/loader.conf" ::/loader/loader.conf
mcopy -o -i "$efi_img" "$work/lukearch-test.conf" ::/loader/entries/lukearch-test.conf

install_log="$LOG_DIR/install-serial.log"
echo "Stage 1: installing from $ISO_PATH (serial log: $install_log)" >&2
timeout "$INSTALL_TIMEOUT" "${QEMU[@]}" \
  -drive "file=$efi_img,if=none,format=raw,readonly=on,id=esp" \
  -device "virtio-blk-pci,drive=esp,bootindex=0" \
  -cdrom "$ISO_PATH" \
  -fw_cfg "name=$fw_cfg_name,file=$GUEST_SCRIPT" \
  -serial "file:$install_log" || true
if ! grep -q 'LUKEARCH-E2E: INSTALL-OK' "$install_log"; then
  # The installer's own messages come before the guest's shutdown, so search the whole log.
  grep -a -E 'LUKEARCH-E2E|error|needs|not |Fix|Choose' "$install_log" | head -n 40 >&2 || true
  echo "Stage 1 failed. Last lines of the serial log:" >&2
  tail -n 60 "$install_log" >&2
  exit 1
fi
echo "Stage 1 passed: the installer finished and the installed files check out." >&2

# Stage 2. Boot the installed disk without the ISO, through its own
# systemd-boot, and wait for SDDM and the serial login prompt.
boot_log="$LOG_DIR/boot-serial.log"
echo "Stage 2: booting the installed disk (serial log: $boot_log)" >&2
: > "$boot_log"
# Fresh firmware variables, so no boot entry from stage 1 is left behind.
cp "${OVMF_CODE/CODE/VARS}" "$work/vars.fd"
"${QEMU[@]}" -serial "file:$boot_log" &
qemu_pid=$!
booted=no
deadline=$(( SECONDS + BOOT_TIMEOUT ))
while (( SECONDS < deadline )) && kill -0 "$qemu_pid" 2>/dev/null; do
  if grep -q 'Simple Desktop Display Manager' "$boot_log" && grep -q 'lukearch login:' "$boot_log"; then
    booted=yes
    break
  fi
  sleep 5
done
kill "$qemu_pid" 2>/dev/null || true
wait "$qemu_pid" 2>/dev/null || true
qemu_pid=""

if [[ "$booted" != "yes" ]]; then
  echo "Stage 2 failed: the installed disk did not reach SDDM and a login prompt. Last lines of the serial log:" >&2
  tail -n 60 "$boot_log" >&2
  exit 1
fi
echo "Stage 2 passed: the installed disk booted to SDDM and a login prompt." >&2
