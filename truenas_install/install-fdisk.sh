#!/bin/bash

# --- 1. 磁盘准备与分区 (基于 image_f21ae8.jpg) ---
udevadm settle
# 清除旧的分区标签与签名
zpool labelclear -f /dev/sda3
wipefs -a /dev/sda
sgdisk -Z /dev/sda

# 创建分区表: 1:BIOS Boot(EF02), 2:EFI(EF00), 3:ZFS(BF01)
sgdisk -a4096 -n1:0:+1024K -t1:EF02 -A1:set:2 /dev/sda
sgdisk -n2:0:+524288K -t2:EF00 /dev/sda
sgdisk -n3:0:0 -t3:BF01 /dev/sda
parted -s /dev/sda disk_set pmbr_boot on

# --- 2. ZFS 池与核心路径创建 (基于 image_f21ae8.jpg) ---
zpool create -f -o ashift=12 -o cachefile=none -o compatibility=grub2 \
    -O acltype=off -O canmount=off -O compression=on -O devices=off \
    -O mountpoint=none -O normalization=formD -O relatime=on -O xattr=sa \
    boot-pool /dev/sda3

zfs create -o canmount=off boot-pool/ROOT
zfs create -o canmount=off -o mountpoint=legacy boot-pool/grub

echo "Installation/Update Step Finished."