#!/bin/bash
if [ $# -ne 3 ]; then
    echo "Usage: $0 <kernel> <rootfs.squashfs> </mnt>"
    echo "Example: $0 zuti-260123 rootfs.squashfs /mnt"
    exit 1
fi

KERNEL="$1"
DATASET=zroot/ROOT/${KERNEL}
ROOTFS="$2"
MNT="$3"
mkdir -p ${MNT}


if zfs list -H -o name "$DATASET" &>/dev/null; then
    echo "Dataset '$DATASET' exists"
    exit 1
fi

zfs create -o mountpoint=${MNT} -o canmount=noauto zroot/ROOT/${KERNEL}
# zfs set mountpoint=${MNT} zroot/ROOT/${KERNEL}
zfs mount zroot/ROOT/${KERNEL}

unsquashfs -d ${MNT} -f -da 16 -fr 16 ${ROOTFS}

zfs set org.zfsbootmenu:commandline="loglevel=7" zroot/ROOT/${KERNEL}
cp /etc/fstab ${MNT}/etc/.

zpool set bootfs=zroot/ROOT/${KERNEL} zroot

mkdir -p "${MNT}/tmp"
chmod +x "${MNT}/usr/bin/dpkg"
chmod +x "${MNT}/usr/bin/apt"
cp ztzbm* "${MNT}/tmp/"

./network-setting.sh ${MNT}

# zfs set mountpoint=/ zroot/ROOT/${KERNEL}

mkdir -p "$MNT/proc" "$MNT/sys" "$MNT/dev" "$MNT/dev/pts"

mount -t proc proc ${MNT}/proc
mount -t sysfs sys ${MNT}/sys
mount -B /dev ${MNT}/dev
mount -t devpts pts ${MNT}/dev/pts
chroot ${MNT}

DELAY=1

while ! umount -R "$MNT" 2>/dev/null; do
    echo "Unmount failed. Retrying in $DELAY second(s)..."
    sleep "$DELAY"
done

echo "Recursive unmount completed successfully."

zfs set mountpoint=/ zroot/ROOT/${KERNEL}

echo "ZFSBootMenu default boot set to "${KERNEL}