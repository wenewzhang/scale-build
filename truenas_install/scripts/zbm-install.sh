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
    echo "  1: sgdisk zgenhostid"
    echo "  2: sgdisk"
    echo "  3: create zroot"
    echo "  4: create dataset"
    echo "  5: mount show"
    echo "  6: chroot into mounted system"
    echo "  7: zpool export/import and mount datasets"
    echo "  8: GRUB-style disk partitioning (./sgdisk-debian.sh)"
    echo "  9: Update GRUB configuration"
    echo " 10: Updating /etc/fstab..."
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



case $STEP in
    1)
        echo ">>> [Step 1]  sgdisk zgenhostid..."
        zgenhostid -f 0x00bab10c
        zpool labelclear -f "$POOL_DISK"

        # wipefs -a "$POOL_DISK"
        wipefs -a "$BOOT_DISK"

        # sgdisk --zap-all "$POOL_DISK"
        sgdisk --zap-all "$BOOT_DISK"
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
        ;;  
    4)
        echo ">>> [Step 4] create dataset"
        zfs create -o mountpoint=none zroot/ROOT
        zfs create -o mountpoint=/ -o canmount=noauto zroot/ROOT/${ID}
        zfs create -o mountpoint=/home zroot/home
        zpool set bootfs=zroot/ROOT/${ID} zroot  
        ;;  
    5)
        echo ">>> [Step 4] mount show"
        udevadm trigger
        mount | grep mnt
        zfs list
        ;;      
    6)
        echo ">>> [Step 6] chroot into mounted system..."
        mount -t proc proc /mnt/proc
        mount -t sysfs sys /mnt/sys
        mount -B /dev /mnt/dev
        mount -t devpts pts /mnt/dev/pts
        chroot /mnt /bin/bash
        ;;
    7)
        echo ">>> [Step 7] zpool export/import and mount datasets..."
        zpool export zroot
        zpool import -N -R /mnt zroot
        zfs mount zroot/ROOT/${ID}
        zfs mount zroot/home
        ;;
    8)
        echo ">>> [Step 8] GRUB-style disk partitioning..."
        ./sgdisk-debian.sh $BOOT_DISK
        ;;
    *)
        echo "others"
        ;;
esac

udevadm trigger