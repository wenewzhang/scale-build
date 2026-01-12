#!/bin/sh

# Usage check
if [ $# -ne 2 ]; then
    cat >&2 <<EOF
Usage: $0 <mode> <disk device>

Modes:
  bios       - Create BIOS boot partition (EF02)
  uefi       - Create EFI System Partition (EF00)
  bootpool   - Create ZFS boot pool partition (BF01)
  uefi-bootpool - Create both EFI System Partition (EF00) and ZFS boot pool (BF01)

It is recommended to use /dev/disk/by-id/ paths for disk devices.

Examples:
  $0 bios /dev/disk/by-id/ata-WDC_...
  $0 uefi /dev/disk/by-id/nvme-...
  $0 bootpool /dev/disk/by-id/...
EOF
    exit 1
fi

MODE="$1"
DISK="$2"

# Validate disk path
if [ ! -b "$DISK" ]; then
    echo "Error: '$DISK' is not a valid block device" >&2
    exit 1
fi

# Show actual device (resolve by-id)
REAL_DEV=$(readlink -f "$DISK")
echo "Target disk: $DISK -> $REAL_DEV"
echo "Mode: $MODE"

# Confirmation
printf "\nThis operation will repartition the disk and destroy all data! Type 'YES' to confirm: "
read -r CONFIRM
[ "$CONFIRM" != "YES" ] && { echo "Cancelled."; exit 1; }

# Clean existing partition table (optional but recommended)
echo "Cleaning existing partition table..."
wipefs -a "$DISK" >/dev/null 2>&1
sgdisk --zap-all "$DISK" >/dev/null 2>&1

# Partition according to mode
case "$MODE" in
    bios)
        echo "Creating BIOS boot partition (EF02)..."
        sgdisk -a1 -n1:24K:+1000K -t1:EF02 "$DISK"
        ;;
    uefi)
        echo "Creating EFI System Partition (EF00)..."
        sgdisk -n1:1M:+512M -t1:EF00 "$DISK"
        ;;
    bootpool)
        echo "Creating ZFS boot pool partition (BF01)..."
        sgdisk -n1:0:+1G -t1:BF01 "$DISK"
        ;;
    uefi-bootpool)
        echo "Creating EFI System Partition (EF00) and ZFS boot pool (BF01)..."
        sgdisk -n1:1M:+512M -t1:EF00 "$DISK"
        sgdisk -n2:0:+1G    -t2:BF01 "$DISK"
        ;;
    *)
        echo "Error: Unknown mode '$MODE'. Supported modes: bios, uefi, bootpool, uefi-bootpool" >&2
        exit 1
        ;;
esac

# Check success
if [ $? -eq 0 ]; then
    echo "Partitioning completed successfully!"
    sgdisk -p "$DISK"
else
    echo "❌ Partitioning failed!"
    exit 1
fi