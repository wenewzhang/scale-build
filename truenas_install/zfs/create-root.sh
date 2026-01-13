#!/usr/bin/env bash

# Strict mode
set -euo pipefail

# Help message
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

zpool create \
    -o ashift=12 \
    -o autotrim=on \
    -O acltype=posixacl -O xattr=sa -O dnodesize=auto \
    -O compression=lz4 \
    -O normalization=formD \
    -O relatime=on \
    -O canmount=off -O mountpoint=/ -R /mnt \
    rpool ${DISK}