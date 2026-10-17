#!/usr/bin/env bash
# Runs inside the live x86_64 ISO during scripts/test-install.sh. It installs
# onto the blank disk with the recommended settings, checks the installed
# files, and prints a LUKEARCH-E2E line that the host looks for. systemd powers
# the machine off when this script exits.
set -uo pipefail
exec > /dev/console 2>&1

PASSWORD=e2e-test-password
ROOT=/tmp/e2e-root

fail() {
  echo "LUKEARCH-E2E: FAIL: $*"
  exit 1
}

# Succeeds when the keyring in $1 holds a distribution master key, the same
# check lukearch-install makes before it erases a disk.
has_master_key() { # gpgdir
  local trusted fpr
  for trusted in /usr/share/pacman/keyrings/*-trusted; do
    fpr="$(grep -m1 -oiE '^[0-9a-f]{40}' "$trusted" || true)"
    if [[ -n "$fpr" ]] && pacman-key --gpgdir "$1" --list-keys "$fpr" >/dev/null 2>&1; then
      return 0
    fi
  done
  return 1
}

echo "LUKEARCH-E2E: guest script started"

# systemd.run= boots straight into this script, so the services a normal boot
# starts are started here. pacman-init must still be enabled for normal boots.
systemctl is-enabled --quiet pacman-init.service || fail "pacman-init.service is not enabled"
systemctl start pacman-init.service || fail "pacman-init.service failed"
has_master_key /etc/pacman.d/gnupg || fail "the live keyring has no distribution master key"
grep -q '^Server' /etc/pacman.d/mirrorlist || fail "the live mirrorlist has no servers"
systemctl start NetworkManager.service || fail "NetworkManager did not start"
nm-online -q -t 180 || fail "no network connection"
udevadm settle
# The target is the writable blank disk. The host attaches the EFI image
# read-only and the ISO as a CD-ROM, and the device names depend on attach order.
DISK="$(lsblk -dnpro NAME,TYPE,RO | awk '$2 == "disk" && $3 == "0" && $1 != "/dev/zram0" { print $1; exit }')"
[[ -n "$DISK" && -b "$DISK" ]] || fail "no writable target disk"
echo "LUKEARCH-E2E: target disk $DISK"

lukearch-install --print-config |
  sed -e "s|^DISK=.*|DISK=$DISK|" -e 's|^CONFIRM_ERASE=.*|CONFIRM_ERASE=yes|' > /tmp/e2e.conf
# The recommended settings ask for the administrator password and the user's
# password, each twice.
printf '%s\n' "$PASSWORD" "$PASSWORD" "$PASSWORD" "$PASSWORD" |
  lukearch-install --config /tmp/e2e.conf
status=$?
[[ $status -eq 0 ]] || fail "lukearch-install exited with status $status"

mkdir -p "$ROOT"
mount "${DISK}2" "$ROOT" || fail "cannot mount the installed root partition"
mount "${DISK}1" "$ROOT/boot" || fail "cannot mount the installed EFI partition"
grep -q '^Server' "$ROOT/etc/pacman.d/mirrorlist" || fail "the installed mirrorlist has no servers"
has_master_key "$ROOT/etc/pacman.d/gnupg" || fail "the installed keyring has no distribution master key"
entry="$ROOT/boot/loader/entries/lukearch.conf"
[[ -f "$entry" ]] || fail "the installed system has no boot entry"
# The second stage reads the installed system's boot messages and login prompt
# from the serial port.
sed -i '/^options / s/$/ console=ttyS0/' "$entry"
umount -R "$ROOT"

echo "LUKEARCH-E2E: INSTALL-OK"
