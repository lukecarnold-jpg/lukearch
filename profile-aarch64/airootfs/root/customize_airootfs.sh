#!/usr/bin/env bash
set -euo pipefail

useradd --create-home --shell /bin/bash lukearch
usermod --append --groups wheel lukearch

# Put the installer launcher on the live user's desktop. The file must be
# executable for Plasma to offer it as a launcher.
install -d -o lukearch -g lukearch -m 0755 /home/lukearch/Desktop
install -o lukearch -g lukearch -m 0755 /usr/share/applications/lukearch-install.desktop /home/lukearch/Desktop/lukearch-install.desktop
passwd --lock lukearch
passwd --lock root

systemctl enable NetworkManager.service
systemctl enable nftables.service
systemctl enable sddm.service
systemctl enable pacman-init.service

# Default locale, timezone, and services for the live image
locale-gen
ln -sf /usr/share/zoneinfo/Australia/Sydney /etc/localtime
systemctl enable bluetooth.service
systemctl enable cups.socket

# archiso copies vmlinuz-<pkgbase> into the ISO; the linux-aarch64 package installs the kernel as Image.
cp /boot/Image /boot/vmlinuz-linux-aarch64
