#!/usr/bin/env bash
set -euo pipefail

useradd --create-home --shell /bin/bash lukearch
usermod --append --groups wheel lukearch
passwd --lock lukearch
passwd --lock root

systemctl enable NetworkManager.service
systemctl enable nftables.service
systemctl enable sddm.service
