#!/bin/bash

# Check if exactly one argument (disk device) is provided
if [ $# -ne 1 ]; then
    echo "Usage: $0 <disk_device>"
    echo "Example: $0 /dev/sda"
    exit 1
fi

DISK="$1"

swapoff --all

# --- 1. Disk preparation and partitioning (based on image_f21ae8.jpg) ---
udevadm settle

# Wipe all filesystem and partition table signatures
wipefs -a "$DISK"
sgdisk -Z "$DISK"

# Create GPT partitions:
#   Partition 1: BIOS Boot (EF02, 1 MiB)
#   Partition 2: EFI System Partition (EF00, 512 MiB = 524288 KiB)
#   Partition 3: ZFS pool partition (BF01, rest of the disk)
sgdisk -a4096 -n1:0:+1024K -t1:EF02 -A1:set:2 "$DISK"
sgdisk -n2:0:+524288K -t2:EF00 "$DISK"
sgdisk -n3:0:+1G -t3:BF01 "$DISK"
sgdisk -n4:0:0 -t4:BF00 "$DISK"
# Enable the 'pmbr_boot' flag for BIOS compatibility with GPT
read -p "Enabling MBR boot flag for BIOS compatibility(legacy BIOS boot, NOT UEFI). (y/N): " -r confirm
if [[ "$confirm" =~ ^[Yy]$ ]]; then
    echo "legacy BIOS boot, NOT UEFI"
    parted -s "$DISK" disk_set pmbr_boot on
else
    echo "Skipping pmbr_boot (assuming UEFI boot)."
fi

partprobe $DISK

echo " Partitioning complete on: $DISK"
echo "  Partition 1: BIOS Boot (EF02)"
echo "  Partition 2: EFI System Partition (EF00, 512 MiB)"
echo "  Partition 3: ZFS Boot Pool (BF01, 1024 MiB)"
echo "  Partition 4: ZFS Root Pool (BF00, remaining space)"