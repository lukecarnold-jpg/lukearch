#!/usr/bin/env bash
set -euo pipefail

ISO_PATH="${1:-}"
if [[ -z "$ISO_PATH" || ! -f "$ISO_PATH" ]]; then
  echo "Usage: $0 /absolute/path/to/lukearch-aarch64.iso" >&2
  exit 1
fi

if ! command -v VBoxManage >/dev/null 2>&1; then
  echo "VirtualBox 7.2+ is required; VBoxManage was not found." >&2
  exit 1
fi

case "$(uname -m)" in
  arm64|aarch64) ;;
  *)
    echo "VirtualBox ARM64 guests require an ARM64 host; this host is $(uname -m)." >&2
    exit 1
    ;;
esac

VM_NAME="${VM_NAME:-Lukearch ARM64}"
MEMORY_MB="${MEMORY_MB:-4096}"
CPUS="${CPUS:-2}"
START_TYPE="${START_TYPE:-gui}"
REPLACE_VM="${REPLACE_VM:-0}"

if VBoxManage showvminfo "$VM_NAME" >/dev/null 2>&1; then
  if [[ "$REPLACE_VM" != "1" ]]; then
    echo "A VM named '$VM_NAME' already exists." >&2
    echo "Set REPLACE_VM=1 to delete it and its disks, or set VM_NAME to use another name." >&2
    exit 1
  fi
  VBoxManage unregistervm "$VM_NAME" --delete
fi

# The ARM platform is required; the default x86 platform creates a piix3 VM that cannot boot the aarch64 ISO.
VBoxManage createvm --name "$VM_NAME" --platform-architecture arm --register
# ARM guests have no PS/2 controller, so the pointer and keyboard must be USB devices.
# qemuramfb is the display that boots reliably; the default VGA device can fail with a RAM conflict.
VBoxManage modifyvm "$VM_NAME" --chipset armv8virtual --firmware efi --memory "$MEMORY_MB" --cpus "$CPUS" \
  --mouse usbtablet --keyboard usb --usb-xhci on --graphicscontroller qemuramfb --nic1 nat
VBoxManage storagectl "$VM_NAME" --name "SATA" --add sata
VBoxManage storageattach "$VM_NAME" --storagectl "SATA" --port 0 --device 0 --type dvddrive --medium "$ISO_PATH"
VBoxManage startvm "$VM_NAME" --type "$START_TYPE"
