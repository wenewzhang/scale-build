#!/bin/bash

FORCE=false
DISK=""

if [ $# -eq 0 ]; then
    echo "Usage: $0 [-f] <disk_device>"
    echo "Example: $0 /dev/sda"
    echo "Example: $0 -f /dev/sda"
    echo "  -f: Force execution without warning"
    exit 1
fi

if [ "$1" = "-f" ]; then
    FORCE=true
    if [ $# -ne 2 ]; then
        echo "Error: -f option requires a disk device"
        echo "Usage: $0 -f <disk_device>"
        exit 1
    fi
    DISK="$2"
else
    if [ $# -ne 1 ]; then
        echo "Usage: $0 [-f] <disk_device>"
        echo "Example: $0 /dev/sda"
        echo "Example: $0 -f /dev/sda"
        echo "  -f: Force execution without warning"
        exit 1
    fi
    DISK="$1"
fi

if [ "$FORCE" = false ]; then
    echo "WARNING: This will clear all data on disk $DISK!"
    echo "All partitions and data will be permanently deleted."
    echo ""
    read -p "Are you sure you want to continue? (y/N): " confirm
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        echo "Operation cancelled."
        exit 1
    fi
fi
./zbm-install.sh $DISK 1
./zbm-install.sh $DISK 13
./zbm-install.sh $DISK 3
./zbm-install.sh $DISK 4
./zbm-install.sh $DISK 5
./zbm-install.sh $DISK 7
./zbm-install.sh $DISK 8
./zbm-install.sh $DISK 9
./network-setting.sh /mnt
./zbm-install.sh $DISK 10
./zbm-install.sh $DISK 11
./zbm-install.sh $DISK 14
./zbm-install.sh $DISK 6
