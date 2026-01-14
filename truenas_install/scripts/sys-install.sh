#!/bin/bash
mkdir /tmp/rootfs
mount -t squashfs /cdrom/TrueNAS-SCALE.update /tmp/rootfs
unsquashfs -d /mnt -f -da 16 -fr 16  /tmp/rootfs/rootfs.squashfs
mkdir -p /mnt/etc/zfs
cp /etc/zfs/zpool.cache /mnt/etc/zfs/