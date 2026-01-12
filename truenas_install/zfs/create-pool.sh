#!/usr/bin/env bash

# 严格模式
set -euo pipefail

# 帮助信息
show_help() {
    cat >&2 <<EOF
用法: $0 <磁盘设备> <类型>

类型:
  boot  - 创建 bpool（用于 /boot，分区3）
  root  - 创建 rpool（用于 /，分区4）

磁盘设备应为 /dev/disk/by-id/... 路径。

示例:
  $0 /dev/disk/by-id/ata-WDC_... boot
  $0 /dev/disk/by-id/nvme-... root
EOF
}

# 参数检查
if [ $# -ne 2 ]; then
    show_help
    exit 1
fi

DISK="$1"
TYPE="$2"

# 验证类型
case "$TYPE" in
    boot|root)
        ;;
    *)
        echo "错误: 类型必须是 'boot' 或 'root'" >&2
        show_help
        exit 1
        ;;
esac

# 验证磁盘是否存在
if [ ! -b "$DISK" ]; then
    echo "错误: '$DISK' 不是一个有效的块设备" >&2
    exit 1
fi

# 确定分区和池名
if [ "$TYPE" = "boot" ]; then
    POOL_NAME="bpool"
    PARTITION="${DISK}-part3"
    MOUNTPOINT="/boot"
elif [ "$TYPE" = "root" ]; then
    POOL_NAME="rpool"
    PARTITION="${DISK}-part4"
    MOUNTPOINT="/"
fi

# 检查分区是否存在
if [ ! -b "$PARTITION" ]; then
    echo "错误: 分区 '$PARTITION' 不存在，请先分区！" >&2
    echo "提示: 可使用 sgdisk 创建对应分区。" >&2
    exit 1
fi

echo "即将创建 ZFS 池:"
echo "  类型:     $TYPE"
echo "  池名:     $POOL_NAME"
echo "  设备:     $PARTITION"
echo "  挂载点:   $MOUNTPOINT (在 /mnt 下)"
echo

printf "⚠️ 此操作将初始化 ZFS 池并覆盖数据！输入 'YES' 确认: "
read -r CONFIRM
if [ "$CONFIRM" != "YES" ]; then
    echo "已取消。"
    exit 1
fi

# 公共选项
COMMON_OPTS=(
    -o ashift=12
    -o autotrim=on
    -O acltype=posixacl
    -O xattr=sa
    -O compression=lz4
    -O normalization=formD
    -O relatime=on
    -O canmount=off
    -O "mountpoint=$MOUNTPOINT"
    -R /mnt
)

# 创建池
if [ "$TYPE" = "boot" ]; then
    # bpool 特有选项
    zpool create \
        "${COMMON_OPTS[@]}" \
        -o compatibility=grub2 \
        -o cachefile=/etc/zfs/zpool.cache \
        -O devices=off \
        "$POOL_NAME" "$PARTITION"
else
    # rpool 特有选项
    zpool create \
        "${COMMON_OPTS[@]}" \
        -O dnodesize=auto \
        "$POOL_NAME" "$PARTITION"
fi

if zpool list "$POOL_NAME" >/dev/null 2>&1; then
    echo "✅ ZFS 池 '$POOL_NAME' 创建成功！"
    zpool status "$POOL_NAME"
else
    echo "❌ 池创建失败！"
    exit 1
fi