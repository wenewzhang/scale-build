#!/usr/bin/env bash

# Strict mode
set -euo pipefail

# Help message
show_help() {
    cat >&2 <<EOF
Usage: $0 <disk device> <type>

Type:
  boot  - Create bpool (for /boot, partition 3)
  root  - Create rpool (for /, partition 4)

The disk device should be a /dev/disk/by-id/... path.

Examples:
  $0 /dev/disk/by-id/ata-WDC_... boot
  $0 /dev/disk/by-id/nvme-... root
EOF
}

# Argument check
if [ $# -ne 2 ]; then
    show_help
    exit 1
fi

DISK="$1"
TYPE="$2"

# Validate type
case "$TYPE" in
    boot|root)
        ;;
    *)
        echo "Error: Type must be 'boot' or 'root'" >&2
        show_help
        exit 1
        ;;
esac

# Verify disk exists
if [ ! -b "$DISK" ]; then
    echo "Error: '$DISK' is not a valid block device" >&2
    exit 1
fi

# Determine partition and pool name
if [ "$TYPE" = "boot" ]; then
    POOL_NAME="bpool"
    PARTITION="${DISK}-part3"
    MOUNTPOINT="/boot"
elif [ "$TYPE" = "root" ]; then
    POOL_NAME="rpool"
    PARTITION="${DISK}-part4"
    MOUNTPOINT="/"
fi

# Check if partition exists
if [ ! -b "$PARTITION" ]; then
    echo "Error: Partition '$PARTITION' does not exist. Please partition the disk first!" >&2
    echo "Hint: Use sgdisk to create the required partition." >&2
    exit 1
fi

echo "About to create ZFS pool:"
echo "  Type:       $TYPE"
echo "  Pool name:  $POOL_NAME"
echo "  Device:     $PARTITION"
echo "  Mountpoint: $MOUNTPOINT (under /mnt)"
echo

printf "⚠️ This operation will initialize a ZFS pool and overwrite data! Type 'YES' to confirm: "
read -r CONFIRM
if [ "$CONFIRM" != "YES" ]; then
    echo "Cancelled."
    exit 1
fi

# Common options
COMMON_OPTS=(
    -o ashift=12
    -o autotrim=on
    -O acltype=posixacl
    -O xattr=sa
    -O compression=lz4
    -O normalization=formD
    -O relatime=on
    -O canmount=off
    -O "mountpoint=$MOUNTPOINT"
    -R /mnt
)

# Create pool
if [ "$TYPE" = "boot" ]; then
    # bpool-specific options
    zpool create \
        "${COMMON_OPTS[@]}" \
        -o compatibility=grub2 \
        -o cachefile=/etc/zfs/zpool.cache \
        -O devices=off \
        "$POOL_NAME" "$PARTITION"
else
    # rpool-specific options
    zpool create \
        "${COMMON_OPTS[@]}" \
        -O dnodesize=auto \
        "$POOL_NAME" "$PARTITION"
fi

if zpool list "$POOL_NAME" >/dev/null 2>&1; then
    echo "✅ ZFS pool '$POOL_NAME' created successfully!"
    zpool status "$POOL_NAME"
else
    echo "❌ Pool creation failed!"
    exit 1
fi