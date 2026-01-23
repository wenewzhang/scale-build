#!/bin/bash

if [ $# -ne 1 ]; then
    echo "Usage: $0 [-f] <disk_device>"
    echo "Example: $0 /dev/sda"
    echo "Example: $0 -f /dev/sda"
    echo "  -f: Force execution without warning"
    exit 1
fi
DISK="$1"
./ztzbm-install.sh $DISK 1
./ztzbm-install.sh $DISK 2
./ztzbm-install.sh $DISK 3
./ztzbm-install.sh $DISK 4
./ztzbm-install.sh $DISK 5
./ztzbm-install.sh $DISK 6
./ztzbm-install.sh $DISK 7
./ztzbm-install.sh $DISK 8
./ztzbm-install.sh $DISK 9
./ztzbm-install.sh $DISK 10
./ztzbm-install.sh $DISK 11
./ztzbm-install.sh $DISK 12
./ztzbm-install.sh $DISK 13
