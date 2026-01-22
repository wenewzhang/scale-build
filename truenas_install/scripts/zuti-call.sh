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

if [ -d /sys/firmware/efi/efivars ]; then
    echo "Installing GRUB for UEFI..."
    ./zuti-install.sh 4 ${DISK}2
else
    echo "Installing GRUB for BIOS..."
    ./zuti-install.sh 6 $DISK
fi
./zuti-install.sh 5
./zuti-install.sh 7
echo 'root:root' | chpasswd
sed -i 's|172\.17\.0\.2:3142/||g' /etc/apt/sources.list