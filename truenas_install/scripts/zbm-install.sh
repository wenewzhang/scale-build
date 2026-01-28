#!/bin/bash
# Check if step is provided as last argument
STEP="$2"

# Basic usage check
if [ -z "$STEP" ]; then
    echo "Usage: $0 [disk_device] <step>"
    echo "Example: $0 /dev/sda 1"
    echo "  1: clean label wipefs & sgdisk --zap-all & zgenhostid..."
    echo "  2: sgdisk"
    echo "  3: create zroot"
    echo "  4: create dataset"
    echo "  5: mount show"
    echo "  6: chroot into mounted system"
    echo "  7: zpool export/import and mount datasets"
    echo "  8: install rootfs to ${MNT}..."
    echo "  9: copy scripts to new system"
    echo " 10: dd write gptmbr to disk(legacy BIOS)."
    echo " 11: syslinux install to disk(legacy BIOS)."
    echo " 12: sgdisk 8300 for legacy BIOS."
    echo " 13: sfdisk 8300 for legacy BIOS."
    echo " 14: extlinux install for legacy BIOS."    
    exit 1
fi

swapoff --all
udevadm settle

# Set disk device if provided (for steps that need it)
BOOT_DISK="$1"
BOOT_PART="1"
BOOT_DEVICE="${BOOT_DISK}${BOOT_PART}"

POOL_DISK="$1"
POOL_PART="2"
POOL_DEVICE="${POOL_DISK}${POOL_PART}"

ID="zuti2601"

MNT="/mnt"

case $STEP in
    1)
        echo ">>> [Step 1]  clean label wipefs & sgdisk --zap-all & zgenhostid..."
        zgenhostid -f 0x00bab10c
        zpool labelclear -f "$POOL_DISK"

        # wipefs -a "$POOL_DISK"
        wipefs -a "$BOOT_DISK"

        # sgdisk --zap-all "$POOL_DISK"
        sgdisk --zap-all "$BOOT_DISK"
        ;;
    2)
        echo ">>> [Step 2] sgdisk..."
        # sgdisk -a4096 -n1:0:+1024K -t1:EF02 -A1:set:2 "$BOOT_DISK"
        sgdisk -n "${BOOT_PART}:1m:+512m" -t "${BOOT_PART}:ef00" "$BOOT_DISK"
        sgdisk -n "${POOL_PART}:0:-10m" -t "${POOL_PART}:bf00" "$POOL_DISK"
        ;;
    3)
        echo ">>> [Step 3] zpool..."
        zpool create -f -o ashift=12 \
        -O compression=lz4 \
        -O acltype=posixacl \
        -O xattr=sa \
        -O relatime=on \
        -o autotrim=on \
        -o compatibility=openzfs-2.3-linux \
        -m none zroot "$POOL_DEVICE"    
        ;;  
    4)
        echo ">>> [Step 4] create dataset"
        zfs create -o mountpoint=none zroot/ROOT
        zfs create -o mountpoint=/ -o canmount=noauto zroot/ROOT/${ID}
        zfs create -o mountpoint=/home zroot/home
        zpool set bootfs=zroot/ROOT/${ID} zroot  
        ;;  
    5)
        echo ">>> [Step 4] mount show"
        udevadm trigger
        mount | grep mnt
        zfs list
        ;;      
    6)
        echo ">>> [Step 6] chroot into mounted system..."
        mkdir -p "$MNT/proc" "$MNT/sys" "$MNT/dev" "$MNT/dev/pts"

        mount -t proc proc ${MNT}/proc
        mount -t sysfs sys ${MNT}/sys
        mount -B /dev ${MNT}/dev
        mount -t devpts pts ${MNT}/dev/pts
        chroot ${MNT} /bin/bash
        ;;
    7)
        echo ">>> [Step 7] zpool export/import and mount datasets..."
        zpool export zroot
        zpool import -N -R /mnt zroot
        zfs mount zroot/ROOT/${ID}
        zfs mount zroot/home
        ;;
    8)
        echo ">>> [Step 8] install rootfs to /mnt..."
        mkdir /tmp/rootfs
        mount -t squashfs /cdrom/TrueNAS-SCALE.update /tmp/rootfs
        unsquashfs -d ${MNT} -f -da 16 -fr 16  /tmp/rootfs/rootfs.squashfs
        ;;
    9)  
        echo ">>> [Step 9] copy scripts to /mnt/tmp/"
        mkdir -p "${MNT}/tmp"
        chmod +x "${MNT}/usr/bin/dpkg"
        chmod +x "${MNT}/usr/bin/apt"
        cp ztzbm* "${MNT}/tmp/"
        cp -rf /cdrom/scripts/zbm ${MNT}/tmp/.        
        ;;
    10)  
        echo ">>> [Step 10] dd write gptmbr to disk(legacy BIOS)"
        dd bs=440 count=1 conv=notrunc if=/usr/lib/syslinux/mbr/gptmbr.bin of=${BOOT_DISK}      
        ;;       
    11)  
        echo ">>> [Step 11] syslinux install to disk(legacy BIOS)."
        mkdir -p ${MNT}/boot/syslinux
        cp /usr/lib/syslinux/modules/bios/*.c32 ${MNT}/boot/syslinux
        syslinux --install ${BOOT_DEVICE}      
        ;;    
    12)  
        echo ">>> [Step 12] sgdisk 8300 for legacy BIOS."
        sgdisk -n 1:2048:+512MiB -t 1:8300 -A 1:set:2 "${POOL_DISK}"
        sgdisk -n 2:0:0 -t 2:BF01 "${POOL_DISK}"  
        ;;  
    13)  
        echo ">>> [Step 13] sfdisk 8300 for legacy BIOS."
cat <<EOF | sfdisk "${POOL_DISK}"
label: dos
start=1MiB, size=512MiB, type=83, bootable
start=513MiB, size=+, type=83
EOF
        ;;  
    14)  
        echo ">>> [Step 14] extlinux install for legacy BIOS."
        extlinux --install /boot/syslinux
        ;;                                 
    *)
        echo "others"
        ;;
esac

udevadm trigger