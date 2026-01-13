#!/bin/bash
show_help() {
    cat >&1 <<EOF
Usage: $0 <disk device>

Type:
  boot  - Create bpool (for /boot, partition 3)

The disk device should be a /dev/disk/by-id/... path.

Examples:
  $0 /dev/disk/by-id/ata-WDC_... 
EOF
}

# Argument check
if [ $# -ne 1 ]; then
    show_help
    exit 1
fi

DISK="$1"

mount --make-private --rbind /dev  /mnt/dev
mount --make-private --rbind /proc /mnt/proc
mount --make-private --rbind /sys  /mnt/sys
chroot /mnt /usr/bin/env DISK=$DISK bash --login