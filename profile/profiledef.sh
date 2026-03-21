#!/usr/bin/env bash
# shellcheck disable=SC2034

iso_name="harborsrv-baseline"
iso_label="HRBSRV_$(date --date="@${SOURCE_DATE_EPOCH:-$(date +%s)}" +%Y%m)"
iso_publisher="J.C. Blouin"
iso_application="Harbor Serve Docker Host"
iso_version="$(date --date="@${SOURCE_DATE_EPOCH:-$(date +%s)}" +%Y.%m.%d)"
install_dir="arch"
buildmodes=('iso')
bootmodes=('bios.syslinux'
           'uefi.grub')
pacman_conf="pacman.conf"
airootfs_image_type="erofs"
airootfs_image_tool_options=('-zlzma,109' -E 'ztailpacking')
bootstrap_tarball_compression=(xz -9e)
file_permissions=(
  ["/etc/shadow"]="0:0:400"
  ["/root/.ssh"]="0:0:700"
  ["/root/.ssh/authorized_keys"]="0:0:600"
  ["/mnt/synology/harbor_srv"]="0:0:755"
)
