#!/bin/bash
if [ $# -ne 1 ]; then
    echo "Error: option requires a disk device"
    echo "Usage: $0 <disk_device>"
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
./ztzbm-enable-root-ssh.sh

echo "Module $0 completed successfully."