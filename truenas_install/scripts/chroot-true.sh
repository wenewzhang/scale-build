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
TEMP_ROOT="/mnt"
mkdir -p "${TEMP_ROOT}/dev"
mkdir -p "${TEMP_ROOT}/proc"
mkdir -p "${TEMP_ROOT}/sys"

# --- 4. 挂载内核虚拟文件系统 ---
mount -t devtmpfs udev $TEMP_ROOT/dev
mount -t proc none $TEMP_ROOT/proc
mount -t sysfs none $TEMP_ROOT/sys

# --- 5. 设定启动属性并进入环境 ---
zpool set bootfs=bpool/BOOT/debian bpool

chroot /mnt /usr/bin/env DISK=$DISK bash --login