#!/usr/bin/env bash
#
# deploy.sh — Deploy a new root image to the inactive A/B partition
#
# Detects the active root, writes the image to the other partition,
# updates systemd-boot to boot the new root, and reboots.
#
# Usage: sudo ./scripts/deploy.sh <root-image.img.zst>
#
set -euo pipefail

IMAGE="${1:-}"

if [ -z "$IMAGE" ]; then
    echo "Usage: $0 <root-image.img.zst>"
    exit 1
fi

if [ "$(id -u)" -ne 0 ]; then
    echo "ERROR: must run as root" >&2
    exit 1
fi

if [ ! -f "$IMAGE" ]; then
    echo "ERROR: ${IMAGE} not found" >&2
    exit 1
fi

CONF="/etc/harbor/partitions.conf"
if [ ! -f "$CONF" ]; then
    echo "ERROR: ${CONF} not found. Was this system installed with install.sh?" >&2
    exit 1
fi

# shellcheck source=/dev/null
source "$CONF"

# Determine active root
ACTIVE_ROOT=$(findmnt -n -o SOURCE /)
echo ":: Active root: ${ACTIVE_ROOT}"

if [ "$ACTIVE_ROOT" = "$ROOT_A_DEV" ]; then
    TARGET_DEV="$ROOT_B_DEV"
    TARGET_ENTRY="harbor-b.conf"
    TARGET_LABEL="Root B"
    TARGET_PARTUUID="$ROOT_B_PARTUUID"
elif [ "$ACTIVE_ROOT" = "$ROOT_B_DEV" ]; then
    TARGET_DEV="$ROOT_A_DEV"
    TARGET_ENTRY="harbor-a.conf"
    TARGET_LABEL="Root A"
    TARGET_PARTUUID="$ROOT_A_PARTUUID"
else
    echo "ERROR: Active root ${ACTIVE_ROOT} doesn't match Root A (${ROOT_A_DEV}) or Root B (${ROOT_B_DEV})" >&2
    exit 1
fi

echo ":: Target: ${TARGET_LABEL} (${TARGET_DEV})"

# Write image to inactive partition
echo ":: Decompressing and writing image..."
zstd -d "$IMAGE" --stdout | dd of="$TARGET_DEV" bs=4M conv=fsync status=progress
sync

# Resize filesystem to fill partition
echo ":: Resizing filesystem..."
e2fsck -f -y "$TARGET_DEV" || true
resize2fs "$TARGET_DEV"

# Mount target to update fstab and copy kernel
MOUNT_DIR="/tmp/harbor-deploy-$$"
mkdir -p "$MOUNT_DIR"
mount "$TARGET_DEV" "$MOUNT_DIR"

# Update fstab in the new root to point to itself
sed -i "s|^PARTUUID=.* / |PARTUUID=${TARGET_PARTUUID}  / |" "${MOUNT_DIR}/etc/fstab"

# Copy partition config to new root
mkdir -p "${MOUNT_DIR}/etc/harbor"
cp "$CONF" "${MOUNT_DIR}/etc/harbor/partitions.conf"

# Copy kernel and initramfs to ESP
ESP_MOUNT=$(findmnt -n -o TARGET /boot/efi 2>/dev/null || echo "")
if [ -z "$ESP_MOUNT" ]; then
    mount "PARTUUID=${ESP_PARTUUID}" /boot/efi
    ESP_MOUNT="/boot/efi"
fi
cp "${MOUNT_DIR}/boot/vmlinuz-linux" "${ESP_MOUNT}/"
cp "${MOUNT_DIR}/boot/initramfs-linux.img" "${ESP_MOUNT}/"

# Switch default boot entry
sed -i "s|^default .*|default ${TARGET_ENTRY}|" "${ESP_MOUNT}/loader/loader.conf"

echo ":: Boot default set to: ${TARGET_ENTRY}"

umount "$MOUNT_DIR"
rmdir "$MOUNT_DIR"

echo ""
echo "=== Deploy complete ==="
echo "New root written to ${TARGET_LABEL} (${TARGET_DEV})"
echo "Rebooting in 5 seconds... (Ctrl+C to cancel)"
sleep 5
reboot
