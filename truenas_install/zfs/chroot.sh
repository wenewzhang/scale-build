#!/bin/bash
mount --make-private --rbind /dev  /mnt/dev
mount --make-private --rbind /proc /mnt/proc
mount --make-private --rbind /sys  /mnt/sys
chroot /mnt /usr/bin/env DISK=$DISK bash --login