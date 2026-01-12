#!/bin/bash
# mkdosfs -F 32 -s 1 -n EFI ${DISK}-part2
# mkdir /boot/efi
# echo /dev/disk/by-uuid/$(blkid -s UUID -o value ${DISK}-part2) \
#    /boot/efi vfat defaults 0 0 >> /etc/fstab
# mount /boot/efi

#!/bin/bash

set -euo pipefail

# === 参数检查 ===
if [ $# -ne 1 ]; then
    echo "用法: $0 <磁盘设备>" >&2
    echo "示例: $0 /dev/disk/by-id/ata-WDC_..." >&2
    exit 1
fi

DISK="$1"

# === 验证分区是否存在 ===
ESP_PART="${DISK}-part2"

if [ ! -b "$ESP_PART" ]; then
    echo "错误: ESP 分区 '$ESP_PART' 不存在！请先用 sgdisk 创建。" >&2
    exit 1
fi

# === 格式化为 FAT32 ===
echo "正在格式化 ESP 分区 ($ESP_PART) 为 FAT32..."
mkdosfs -F 32 -s 1 -n EFI "$ESP_PART" >/dev/null

# === 获取 UUID（更可靠）===
ESP_UUID=$(blkid -s UUID -o value "$ESP_PART")

if [ -z "$ESP_UUID" ]; then
    echo "错误: 无法获取 ESP 分区的 UUID" >&2
    exit 1
fi

# === 挂载点处理（假设在 /mnt 中安装系统）===
# 在 Live CD 安装环境中，目标系统的 /boot/efi 通常是 /mnt/boot/efi
TARGET_BOOT_EFI="/mnt/boot/efi"

# 创建目录（-p 避免报错）
mkdir -p "$TARGET_BOOT_EFI"

# === 写入目标系统的 /etc/fstab（不是当前系统的！）===
FSTAB="/mnt/etc/fstab"

# 防止重复写入（可选）
if ! grep -q "UUID=$ESP_UUID" "$FSTAB" 2>/dev/null; then
    echo "UUID=$ESP_UUID /boot/efi vfat defaults,uid=0,gid=0,umask=077,shortname=winnt 0 2" >> "$FSTAB"
    echo "✅ 已写入 /etc/fstab 条目"
else
    echo "⚠️ /etc/fstab 中已存在该 ESP 条目，跳过"
fi

# === 挂载到目标系统目录 ===
if ! mountpoint -q "$TARGET_BOOT_EFI"; then
    mount "$ESP_PART" "$TARGET_BOOT_EFI"
    echo "✅ ESP 已挂载到 $TARGET_BOOT_EFI"
else
    echo "⚠️ $TARGET_BOOT_EFI 已挂载"
fi