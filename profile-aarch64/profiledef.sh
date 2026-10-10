#!/usr/bin/env bash

iso_name="lukearch-aarch64"
iso_label="LUKEARCH_ARM_$(date +%Y%m)"
iso_publisher="Lukearch Project <https://github.com/lukecarnold-jpg/lukearch>"
iso_application="Lukearch ARM64 Live ISO (Arch Linux ARM-based, unofficial)"
iso_version="$(date +%Y.%m.%d)"
install_dir="arch"
buildmodes=('iso')
bootmodes=('uefi.systemd-boot')
arch='aarch64'
pacman_conf='pacman.conf'
airootfs_image_type='squashfs'

file_permissions=(
  ["/etc/shadow"]="0:0:400"
  ["/root"]="0:0:750"
  ["/root/README"]="0:0:644"
  ["/root/customize_airootfs.sh"]="0:0:755"
  ["/etc/nftables.conf"]="0:0:644"
  ["/etc/sddm.conf.d/autologin.conf"]="0:0:644"
  ["/etc/sudoers.d/lukearch"]="0:0:440"
  ["/usr/local/sbin/lukearch-set-admin-password"]="0:0:755"
)
