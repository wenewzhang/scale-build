#!/bin/sh

if [ $# -ne 1 ]; then
    echo "Usage: $0 <disk device path>" >&2
    echo "It is recommended to use a /dev/disk/by-id/ path, for example:" >&2
    echo "  $0 /dev/disk/by-id/ata-WDC_WD10EZEX-00WN4A0_WD-WCC6Y7FJ5LA9" >&2
    exit 1
fi

DISK="$1"

# Check if path starts with /dev/disk/by-id/ (optional but recommended)
case "$DISK" in
    /dev/disk/by-id/*)
        # OK
        ;;
    /dev/[a-z]* | /dev/nvme[0-9]*n[0-9]* | /dev/mmcblk[0-9]*)
        echo "Warning: You are using a non-by-id path ($DISK). It is recommended to use /dev/disk/by-id/ to avoid device name drift." >&2
        ;;
    *)
        echo "Error: Invalid device path format" >&2
        exit 1
        ;;
esac

# Resolve real device (for display and double-checking)
REAL_DEV=$(readlink -f "$DISK" 2>/dev/null)

if [ ! -b "$DISK" ]; then
    echo "Error: '$DISK' is not a valid block device" >&2
    exit 1
fi

# Safety confirmation (show both by-id and real device)
echo "About to erase the following disk:"
echo "  By-ID path: $DISK"
echo "  Real device: $REAL_DEV"
echo
echo "This operation will permanently delete all data!"
printf "Please type 'YES' to confirm: "
read -r CONFIRM

if [ "$CONFIRM" != "YES" ]; then
    echo "Operation cancelled."
    exit 1
fi

# Perform cleanup
swapoff --all
wipefs -a "$DISK"
sgdisk --zap-all "$DISK"

# Optional: Trigger udev reload (needed on some systems)
udevadm settle

echo "Disk has been successfully wiped: $DISK ($REAL_DEV)"