#!/bin/bash
zfs create -o canmount=off -o mountpoint=none rpool/ROOT
zfs create -o canmount=noauto -o mountpoint=/ rpool/ROOT/debian
zfs mount rpool/ROOT/debian
zfs create                     rpool/home
zfs create -o mountpoint=/root rpool/home/root
chmod 700 /mnt/root
zfs create -o canmount=off     rpool/var
zfs create -o canmount=off     rpool/var/lib
zfs create                     rpool/var/log
zfs create                     rpool/var/spool

## The /boot dataset is under the / dataset, so create rpool then bpool
zfs create -o canmount=off -o mountpoint=none bpool/BOOT
zfs create -o mountpoint=/boot bpool/BOOT/debian
