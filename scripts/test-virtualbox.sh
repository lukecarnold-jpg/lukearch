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

if VBoxManage showvminfo "$VM_NAME" >/dev/null 2>&1; then
  VBoxManage unregistervm "$VM_NAME" --delete
fi

# The ARM platform is required; the default x86 platform creates a piix3 VM that cannot boot the aarch64 ISO.
VBoxManage createvm --name "$VM_NAME" --platform-architecture arm --register
VBoxManage modifyvm "$VM_NAME" --chipset armv8virtual --firmware efi --memory "$MEMORY_MB" --cpus "$CPUS"
VBoxManage storagectl "$VM_NAME" --name "IDE" --add ide
VBoxManage storageattach "$VM_NAME" --storagectl "IDE" --port 0 --device 0 --type dvddrive --medium "$ISO_PATH"
VBoxManage startvm "$VM_NAME" --type gui
