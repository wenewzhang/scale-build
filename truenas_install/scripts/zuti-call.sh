#!/bin/bash
if [ $# -ne 1 ]; then
    echo "Usage: $0 <disk_device>"
    echo "Example: $0 /dev/sda"
    exit 1
fi

DISK="$1"
./zuti-install.sh 1
./zuti-install.sh 2
./zuti-install.sh 3

if [ ! -d /sys/firmware/efi/efivars ]; then
    echo "Enabling MBR boot flag for BIOS compatibility(legacy BIOS boot, NOT UEFI)"
    ./zuti-install.sh 4 ${DISK}2
else
    ./zuti-install.sh 6 $DISK
fi
./zuti-install.sh 5
./zuti-install.sh 7