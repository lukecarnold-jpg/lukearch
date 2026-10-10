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

VM_NAME="${VM_NAME:-Lukearch ARM64}"
MEMORY_MB="${MEMORY_MB:-4096}"
CPUS="${CPUS:-2}"

if VBoxManage showvminfo "$VM_NAME" >/dev/null 2>&1; then
  VBoxManage unregistervm "$VM_NAME" --delete
fi

VBoxManage createvm --name "$VM_NAME" --ostype "ArchLinux_64" --register
VBoxManage modifyvm "$VM_NAME" --firmware efi --memory "$MEMORY_MB" --cpus "$CPUS"
VBoxManage storagectl "$VM_NAME" --name "IDE" --add ide
VBoxManage storageattach "$VM_NAME" --storagectl "IDE" --port 0 --device 0 --type dvddrive --medium "$ISO_PATH"
VBoxManage startvm "$VM_NAME" --type gui
