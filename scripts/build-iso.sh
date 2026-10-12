#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

ARCH="${ARCH:-x86_64}"
PROFILE_DIR="${PROFILE_DIR:-}"
WORK_DIR="${WORK_DIR:-$REPO_ROOT/work}"
OUT_DIR="${OUT_DIR:-$REPO_ROOT/out}"

usage() {
  cat <<USAGE
Usage: $0 [--profile DIR] [--work DIR] [--out DIR]

Builds the Lukearch ISO profile with mkarchiso.

Environment overrides:
  ARCH         Target architecture: x86_64 or aarch64 (default: x86_64)
  PROFILE_DIR  Archiso profile path (default depends on ARCH)
  WORK_DIR     mkarchiso work directory (default: $REPO_ROOT/work)
  OUT_DIR      mkarchiso output directory (default: $REPO_ROOT/out)
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --profile)
      PROFILE_DIR="$2"
      shift 2
      ;;
    --work)
      WORK_DIR="$2"
      shift 2
      ;;
    --out)
      OUT_DIR="$2"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unsupported argument: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
done

case "$ARCH" in
  x86_64) DEFAULT_PROFILE_DIR="$REPO_ROOT/profile" ;;
  aarch64) DEFAULT_PROFILE_DIR="$REPO_ROOT/profile-aarch64" ;;
  *)
    echo "Unsupported target architecture: $ARCH" >&2
    exit 1
    ;;
esac
PROFILE_DIR="${PROFILE_DIR:-$DEFAULT_PROFILE_DIR}"

if [[ "$ARCH" == "x86_64" && "$(uname -m)" != "x86_64" ]]; then
  cat >&2 <<ERR
Unsupported host architecture: $(uname -m)

Building the x86_64 profile needs an x86_64 Linux host (or an x86_64
container or VM). For ARM64, set ARCH=aarch64 and build on an ARM64 Linux
host; see docs/arm-support.md.
ERR
  exit 1
fi

if [[ "$ARCH" == "aarch64" && "$(uname -m)" != "aarch64" ]]; then
  cat >&2 <<ERR
Cross-building the aarch64 profile is not supported by this script.
Run it on an ARM64 Linux build host.
ERR
  exit 1
fi

if ! command -v mkarchiso >/dev/null 2>&1; then
  echo "Missing required dependency: mkarchiso" >&2
  echo "Install on Arch Linux with: sudo pacman -S --needed archiso" >&2
  exit 1
fi

for required in "$PROFILE_DIR/profiledef.sh" "$PROFILE_DIR/packages.$ARCH" "$PROFILE_DIR/pacman.conf"; do
  if [[ ! -f "$required" ]]; then
    echo "Missing required profile file: $required" >&2
    exit 1
  fi
done

mkdir -p "$WORK_DIR" "$OUT_DIR"

# Packages such as xorg-server ship paths that differ only by case, which a
# case-insensitive filesystem cannot hold.
case_probe="$(mktemp -d "$WORK_DIR/.case-probe.XXXXXX")"
touch "$case_probe/a" "$case_probe/A"
case_files="$(find "$case_probe" -type f | wc -l | tr -d ' ')"
rm -rf "$case_probe"
if [[ "$case_files" != "2" ]]; then
  echo "WORK_DIR is on a case-insensitive filesystem: $WORK_DIR" >&2
  echo "Use a case-sensitive filesystem for WORK_DIR, for example a Linux filesystem." >&2
  exit 1
fi

if [[ $EUID -eq 0 ]]; then
  MKARCHISO=(mkarchiso)
else
  if ! command -v sudo >/dev/null 2>&1; then
    echo "sudo is required when not running as root." >&2
    exit 1
  fi
  MKARCHISO=(sudo mkarchiso)
fi

"${MKARCHISO[@]}" -v -w "$WORK_DIR" -o "$OUT_DIR" "$PROFILE_DIR"
