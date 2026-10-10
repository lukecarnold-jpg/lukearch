#!/usr/bin/env bash

iso_name="lukearch"
iso_label="LUKEARCH_$(date +%Y%m)"
iso_publisher="Lukearch Project <https://github.com/lukecarnold-jpg/lukearch>"
iso_application="Lukearch Live ISO (Arch-based, unofficial)"
iso_version="$(date +%Y.%m.%d)"
install_dir="arch"
buildmodes=('iso')
bootmodes=(
  'bios.syslinux.mbr'
  'bios.syslinux.eltorito'
  'uefi-x64.systemd-boot.esp'
  'uefi-x64.systemd-boot.eltorito'
)
arch='x86_64'
pacman_conf='pacman.conf'
airootfs_image_type='squashfs'
airootfs_image_tool_options=('comp' 'xz' '-Xbcj' 'x86')

file_permissions=(
  ["/etc/shadow"]="0:0:400"
  ["/root"]="0:0:750"
  ["/root/README"]="0:0:644"
  ["/root/customize_airootfs.sh"]="0:0:755"
  ["/etc/nftables.conf"]="0:0:644"
  ["/etc/sddm.conf.d/autologin.conf"]="0:0:644"
  ["/etc/sudoers.d/lukearch"]="0:0:440"
)
