#!/usr/bin/env bash
set -euo pipefail

useradd --create-home --shell /bin/bash lukearch
usermod --append --groups wheel lukearch
passwd --lock lukearch
passwd --lock root

systemctl enable NetworkManager.service
systemctl enable nftables.service
systemctl enable sddm.service

# Default locale, timezone, and services for the live image
locale-gen
ln -sf /usr/share/zoneinfo/Australia/Sydney /etc/localtime
systemctl enable bluetooth.service
systemctl enable cups.service

# archiso copies vmlinuz-<pkgbase> into the ISO; the linux-aarch64 package installs the kernel as Image.
cp /boot/Image /boot/vmlinuz-linux-aarch64
