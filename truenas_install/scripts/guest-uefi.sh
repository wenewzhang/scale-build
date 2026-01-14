#!/bin/bash
if [ $# -ne 1 ]; then
    echo "Usage: $0 <disk_device>"
    echo "Example: $0 /dev/sda2"
    exit 1
fi

DISK="$1"


mkdosfs -F 32 -s 1 -n EFI ${DISK}
mkdir -p /boot/efi
echo /dev/disk/by-uuid/$(blkid -s UUID -o value ${DISK}) \
   /boot/efi vfat defaults 0 0 >> /etc/fstab
mount /boot/efi
echo "UEFI has been successfully installed on: $DISK"