#!/bin/sh

# 用法检查
if [ $# -ne 2 ]; then
    cat >&2 <<EOF
用法: $0 <模式> <磁盘设备>

模式:
  bios       - 创建 BIOS boot 分区 (EF02)
  uefi       - 创建 EFI 系统分区 (EF00)
  bootpool   - 创建 ZFS boot pool 分区 (BF01)

磁盘设备建议使用 /dev/disk/by-id/ 路径。

示例:
  $0 bios /dev/disk/by-id/ata-WDC_...
  $0 uefi /dev/disk/by-id/nvme-...
  $0 bootpool /dev/disk/by-id/...
EOF
    exit 1
fi

MODE="$1"
DISK="$2"

# 验证磁盘路径
if [ ! -b "$DISK" ]; then
    echo "错误: '$DISK' 不是一个有效的块设备" >&2
    exit 1
fi

# 显示实际设备（解析 by-id）
REAL_DEV=$(readlink -f "$DISK")
echo "目标磁盘: $DISK -> $REAL_DEV"
echo "模式: $MODE"

# 确认
printf "\n⚠️ 此操作将重新分区并破坏所有数据！输入 'YES' 确认: "
read -r CONFIRM
[ "$CONFIRM" != "YES" ] && { echo "已取消."; exit 1; }

# 清理现有分区表（可选但推荐）
echo "正在清理现有分区表..."
wipefs -a "$DISK" >/dev/null 2>&1
sgdisk --zap-all "$DISK" >/dev/null 2>&1

# 根据模式分区
case "$MODE" in
    bios)
        echo "创建 BIOS boot 分区 (EF02)..."
        sgdisk -a1 -n1:24K:+1000K -t1:EF02 "$DISK"
        ;;
    uefi)
        echo "创建 EFI 系统分区 (EF00)..."
        sgdisk -n1:1M:+512M -t1:EF00 "$DISK"
        ;;
    bootpool)
        echo "创建 ZFS boot pool 分区 (BF01)..."
        sgdisk -n1:0:+1G -t1:BF01 "$DISK"
        ;;
    uefi-bootpool)
        sgdisk -n1:1M:+512M -t1:EF00 "$DISK"
        sgdisk -n2:0:+1G    -t2:BF01 "$DISK"
        ;;        
    *)
        echo "错误: 未知模式 '$MODE'。支持: bios, uefi, bootpool" >&2
        exit 1
        ;;
esac

# 检查是否成功
if [ $? -eq 0 ]; then
    echo "✅ 分区成功完成！"
    sgdisk -p "$DISK"
else
    echo "❌ 分区失败！"
    exit 1
fi