#!/bin/bash

# Check if exactly one argument (disk device) is provided
if [ $# -ne 2 ]; then
    echo "Usage: $0 <disk_device> <step>"
    echo "Example: $0 /dev/sda 1"
    exit 1
fi

DISK="$1"

STEP="$2"

# Basic usage check
if [ -z "$STEP" ]; then
    echo "Usage: $0 [1-7] [additional arguments for step 6]"
    echo "Steps:"
    echo "  1: zgenhostid"
    echo "  2: sgdisk"
    echo "  3: create zroot"
    echo "  4: mount show"
    echo "  5: Update Initramfs (all kernels)"
    echo "  6: Install GRUB to specific disk (Requires 2 arguments: e.g.,<6> <disk>)"
    echo "  7: Update GRUB configuration"
    echo "  8: Updating /etc/fstab..."
    exit 1
fi

swapoff --all
udevadm settle

BOOT_DISK="$1"
BOOT_PART="2"
BOOT_DEVICE="${BOOT_DISK}${BOOT_PART}"

POOL_DISK="$1"
POOL_PART="3"
POOL_DEVICE="${POOL_DISK}${POOL_PART}"

ID="zuti2601"

zpool labelclear -f "$POOL_DISK"

# wipefs -a "$POOL_DISK"
wipefs -a "$BOOT_DISK"

# sgdisk --zap-all "$POOL_DISK"
sgdisk --zap-all "$BOOT_DISK"

case $STEP in
    1)
        echo ">>> [Step 1] zgenhostid..."
        zgenhostid -f 0x00bab10c
        ;;
    2)
        echo ">>> [Step 2] sgdisk..."
        sgdisk -a4096 -n1:0:+1024K -t1:EF02 -A1:set:2 "$BOOT_DISK"
        sgdisk -n "${BOOT_PART}:1m:+512m" -t "${BOOT_PART}:ef00" "$BOOT_DISK"
        sgdisk -n "${POOL_PART}:0:-10m" -t "${POOL_PART}:bf00" "$POOL_DISK"
        ;;
    3)
        echo ">>> [Step 3] zpool..."
        zpool create -f -o ashift=12 \
        -O compression=lz4 \
        -O acltype=posixacl \
        -O xattr=sa \
        -O relatime=on \
        -o autotrim=on \
        -o compatibility=openzfs-2.2-linux \
        -m none zroot "$POOL_DEVICE"

        zfs create -o mountpoint=none zroot/ROOT
        zfs create -o mountpoint=/ -o canmount=noauto zroot/ROOT/${ID}
        zfs create -o mountpoint=/home zroot/home
        zpool set bootfs=zroot/ROOT/${ID} zroot  
        zpool export zroot

        zpool import -N -R /mnt zroot
        zfs mount zroot/ROOT/${ID}
        zfs mount zroot/home      
        ;;  
    4)
        echo ">>> [Step 4] udevadm"
        udevadm trigger
        mount | grep mnt
        ;;      
    *)
        echo "others"
        ;;
esac

udevadm trigger