#!/bin/bash
TEMP_ROOT="/mnt"
mkdir -p "${TEMP_ROOT}/dev/pts"
mkdir -p "${TEMP_ROOT}/proc"
mkdir -p "${TEMP_ROOT}/sys"

# --- 4. 挂载内核虚拟文件系统 ---
mount -t devtmpfs udev $TEMP_ROOT/dev
mount -t proc none $TEMP_ROOT/proc
mount -t sysfs none $TEMP_ROOT/sys
mount -B /sys/firmware/efi/efivars /mnt/sys/firmware/efi/efivars
# --- 5. 设定启动属性并进入环境 ---
zpool set bootfs=bpool/BOOT/debian bpool

chroot /mnt bash