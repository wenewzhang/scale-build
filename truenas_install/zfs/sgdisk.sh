#!/bin/sh
swapoff --all
wipefs -a $DISK
sgdisk --zap-all $DISK#!/bin/sh

if [ $# -ne 1 ]; then
    echo "用法: $0 <磁盘设备路径>" >&2
    echo "建议使用 /dev/disk/by-id/ 路径，例如:" >&2
    echo "  $0 /dev/disk/by-id/ata-WDC_WD10EZEX-00WN4A0_WD-WCC6Y7FJ5LA9" >&2
    exit 1
fi

DISK="$1"

# 检查是否以 /dev/disk/by-id/ 开头（可选但推荐）
case "$DISK" in
    /dev/disk/by-id/*)
        # OK
        ;;
    /dev/[a-z]* | /dev/nvme[0-9]*n[0-9]* | /dev/mmcblk[0-9]*)
        echo "警告：你使用了非 by-id 路径（$DISK）。建议改用 /dev/disk/by-id/ 以避免设备名漂移。" >&2
        ;;
    *)
        echo "错误：无效的设备路径格式" >&2
        exit 1
        ;;
esac

# 解析真实设备（用于提示和双重检查）
REAL_DEV=$(readlink -f "$DISK" 2>/dev/null)

if [ ! -b "$DISK" ]; then
    echo "错误: '$DISK' 不是一个有效的块设备" >&2
    exit 1
fi

# 安全确认（显示 by-id 和实际设备）
echo "即将擦除以下磁盘："
echo "  By-ID 路径: $DISK"
echo "  实际设备:  $REAL_DEV"
echo
echo "⚠️ 此操作将永久删除所有数据！"
printf "请输入 'YES' 确认: "
read -r CONFIRM

if [ "$CONFIRM" != "YES" ]; then
    echo "操作已取消。"
    exit 1
fi

# 执行清理
swapoff --all
wipefs -a "$DISK"
sgdisk --zap-all "$DISK"

# 可选：触发 udev 重载（某些系统需要）
udevadm settle

echo "✅ 磁盘已清理完毕：$DISK ($REAL_DEV)"