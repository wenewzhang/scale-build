#!/bin/bash

if [ $# -ne 1 ]; then
    echo "Usage: $0 [-f] <disk_device>"
    echo "Example: $0 /dev/sda"
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
./ztzbm-install.sh $DISK 13
./ztzbm-install.sh $DISK 16
./ztzbm-install.sh $DISK 17
./ztzbm-install.sh $DISK 18
./ztzbm-install.sh $DISK 19
./ztzbm-install.sh $DISK 20