#!/bin/bash
if [ $# -ne 1 ]; then
    echo "Usage: $0 <disk_device>"
    echo "Example: $0 /dev/sda"
    exit 1
fi

DISK="$1"
./sgdisk-debian.sh $DISK
./create-boot.sh ${DISK}3
./create-root.sh ${DISK}4
./create-data.sh 
./sys-install.sh
./init-guest.sh
./chroot2.sh