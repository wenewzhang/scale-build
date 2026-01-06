#!/bin/bash

# --- 1. 环境初始化与数据集创建 ---
# 获取当前启动池状态
zpool get -H -o value bootfs boot-pool
zfs list -H -o name

# 创建新的根数据集 (Root Dataset)
# truenas:kernel_version 对应你图片中的 6.12.57+deb13-amd64
zfs create -o mountpoint=legacy \
           -o truenas:kernel_version=6.12.57+deb13-amd64 \
           -o zectl:keep=False \
           boot-pool/ROOT/zuti-0.1

# 批量创建 FHS 子数据集
# 这里包含了 audit, conf, data, mnt, etc, home, opt, root, usr, var 等
# 并根据安全需求设置了 setuid=off, devices=off, exec=off 等属性
zfs create -u -o mountpoint=legacy -o canmount=noauto -o setuid=off -o devices=off -o exec=off -o acltype=off -o aclmode=discard -o atime=off boot-pool/ROOT/zuti-0.1/audit
zfs create -u -o mountpoint=legacy -o canmount=noauto -o setuid=off -o devices=off -o exec=off -o acltype=off -o aclmode=discard boot-pool/ROOT/zuti-0.1/conf
zfs create -u -o mountpoint=legacy -o canmount=noauto -o setuid=off -o devices=off -o exec=off -o acltype=off -o aclmode=discard -o atime=off boot-pool/ROOT/zuti-0.1/data
zfs create -u -o mountpoint=legacy -o canmount=noauto -o setuid=off -o devices=off -o exec=off -o acltype=off -o aclmode=discard -o atime=off boot-pool/ROOT/zuti-0.1/mnt
zfs create -u -o mountpoint=legacy -o canmount=noauto -o setuid=off -o devices=off -o acltype=off -o aclmode=discard boot-pool/ROOT/zuti-0.1/etc
zfs create -u -o mountpoint=legacy -o canmount=noauto -o setuid=off -o devices=off -o exec=off -o acltype=off -o aclmode=discard boot-pool/ROOT/zuti-0.1/home
zfs create -u -o mountpoint=legacy -o canmount=noauto -o setuid=off -o devices=off -o exec=off -o acltype=off -o aclmode=discard boot-pool/ROOT/zuti-0.1/opt
zfs create -u -o mountpoint=legacy -o canmount=noauto -o setuid=off -o devices=off -o exec=off -o acltype=off -o aclmode=discard boot-pool/ROOT/zuti-0.1/root
zfs create -u -o mountpoint=legacy -o canmount=noauto -o acltype=off -o aclmode=discard -o atime=off boot-pool/ROOT/zuti-0.1/usr
zfs create -u -o mountpoint=legacy -o canmount=noauto -o setuid=off -o devices=off -o acltype=off -o aclmode=discard -o atime=off boot-pool/ROOT/zuti-0.1/var
zfs create -u -o mountpoint=legacy -o canmount=noauto -o setuid=off -o devices=off -o acltype=off -o aclmode=discard -o atime=off boot-pool/ROOT/zuti-0.1/var/ca-certificates
zfs create -u -o mountpoint=legacy -o canmount=noauto -o setuid=off -o devices=off -o acltype=off -o aclmode=discard -o atime=off boot-pool/ROOT/zuti-0.1/var/lib
zfs create -u -o mountpoint=legacy -o canmount=noauto -o setuid=off -o devices=off -o acltype=off -o aclmode=discard -o atime=off boot-pool/ROOT/zuti-0.1/var/lib/incus
zfs create -u -o mountpoint=legacy -o canmount=noauto -o setuid=off -o devices=off -o exec=off -o acltype=off -o aclmode=discard -o atime=off boot-pool/ROOT/zuti-0.1/var/log
zfs create -u -o mountpoint=legacy -o canmount=noauto -o setuid=off -o devices=off -o exec=off -o acltype=posixacl -o aclmode=discard -o atime=off boot-pool/ROOT/zuti-0.1/var/log/journal

# --- 2. 挂载数据集到临时目录 ---
TEMP_ROOT="/tmp/tmprfbeu5y2"
mkdir -p $TEMP_ROOT

mount -t zfs boot-pool/ROOT/zuti-0.1 $TEMP_ROOT
                    
# 假设 TEMP_ROOT 已定义，例如：TEMP_ROOT="/tmp/tmprfbeu5y2"

# 基础目录列表（基于 TRUENAS_DATASETS 定义）
sub_datasets=("audit" "conf" "data" "mnt" "etc" "home" "opt" "root" "usr" "var")

for ds in "${sub_datasets[@]}"; do
    # 创建子目录挂载点
    mkdir -p "${TEMP_ROOT}/${ds}"
done


mount -t zfs boot-pool/ROOT/zuti-0.1/audit $TEMP_ROOT/audit
mount -t zfs boot-pool/ROOT/zuti-0.1/conf $TEMP_ROOT/conf
mount -t zfs boot-pool/ROOT/zuti-0.1/data $TEMP_ROOT/data
mount -t zfs boot-pool/ROOT/zuti-0.1/mnt $TEMP_ROOT/mnt
mount -t zfs boot-pool/ROOT/zuti-0.1/etc $TEMP_ROOT/etc
mount -t zfs boot-pool/ROOT/zuti-0.1/home $TEMP_ROOT/home
mount -t zfs boot-pool/ROOT/zuti-0.1/opt $TEMP_ROOT/opt
mount -t zfs boot-pool/ROOT/zuti-0.1/root $TEMP_ROOT/root
mount -t zfs boot-pool/ROOT/zuti-0.1/usr $TEMP_ROOT/usr
mount -t zfs boot-pool/ROOT/zuti-0.1/var $TEMP_ROOT/var


mkdir /tmp/rootfs
mount -t squashfs /cdrom/TrueNAS-SCALE.update /tmp/rootfs
unsquashfs -d $TEMP_ROOT -f -da 16 -fr 16  /tmp/rootfs/rootfs.squashfs

# --- 3. 配置文件拷贝与权限设置 ---
cp /etc/hostid $TEMP_ROOT/etc/
cp -r /data/. $TEMP_ROOT/data/

# 设置特定目录权限与所有者
chmod -R u=rwX,g=,o= $TEMP_ROOT/data
chmod u=rwx,g=rx,o=rx $TEMP_ROOT/data
chmod -R u=rwX,g=rx,o=rx $TEMP_ROOT/data/subsystems
chown -R 986:986 $TEMP_ROOT/data/subsystems/vm/nvram
chmod -R u=rwX,g=,o= $TEMP_ROOT/data/zfs
chmod u=rwX,g=,o= $TEMP_ROOT/data/sentinels

# 初始化 Machine ID
systemd-machine-id-setup --root=$TEMP_ROOT

# --- 4. 挂载内核虚拟文件系统 ---
mount -t devtmpfs udev $TEMP_ROOT/dev
mount -t proc none $TEMP_ROOT/proc
mount -t sysfs none $TEMP_ROOT/sys
mount -t zfs boot-pool/grub $TEMP_ROOT/boot/grub

# --- 5. 设定启动属性并进入环境 ---
zpool set bootfs=boot-pool/ROOT/zuti-0.1 boot-pool

# 进入 Chroot 执行 grub 更新
# 注意：图片中显示此步骤后可能紧接着 destroy 操作，通常用于清理或回滚
chroot $TEMP_ROOT /usr/bin/sh -c "PATH=/usr/sbin:/usr/bin:/sbin:/bin update-grub"

# 如果需要清理 (慎用，对应最后一张图的 zfs destroy)
# zfs destroy -r boot-pool/ROOT/zuti-0.1  s