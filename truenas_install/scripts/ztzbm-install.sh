#!/bin/bash

BOOT_DISK="$1"
BOOT_PART="2"
BOOT_DEVICE="${BOOT_DISK}${BOOT_PART}"

MODULE="$2"

if [ -z "$MODULE" ]; then
    echo "Usage: $0 <boot_disk> <module_number>"
    echo "Available modules:"
    echo "  1  - Set hostname and hosts file"
    echo "  2  - Configure APT sources"
    echo "  3  - Reconfigure locales and timezone"
    echo "  4  - Configure DKMS ZFS"
    echo "  5  - Enable ZFS services"
    echo "  6  - Update initramfs"
    echo "  7  - Set ZFSBootMenu commandline"
    echo "  8  - Format boot partition"
    echo "  9  - Configure fstab and mount boot"
    echo "  10 - Mount efivarfs"
    echo "  11 - Create ZFSBootMenu backup boot entry"
    echo "  12 - Create ZFSBootMenu main boot entry"
    echo "  13 - Set root password and clean APT proxy"
    exit 1
fi

case $MODULE in
    1)
        echo "Module 1: Setting hostname and hosts file"
        echo 'YOURHOSTNAME' > /etc/hostname
        echo -e '127.0.1.1\tYOURHOSTNAME' >> /etc/hosts
        ;;
    2)
        echo "Module 2: Configuring APT sources"
        cat <<EOF > /etc/apt/sources.list
deb http://deb.debian.org/debian/ trixie main non-free-firmware contrib
deb-src http://deb.debian.org/debian/ trixie main non-free-firmware contrib

deb http://deb.debian.org/debian-security trixie-security main non-free-firmware contrib
deb-src http://deb.debian.org/debian-security/ trixie-security main non-free-firmware contrib

# trixie-updates, to get updates before a point release is made;
deb http://deb.debian.org/debian trixie-updates main non-free-firmware contrib
deb-src http://deb.debian.org/debian trixie-updates main non-free-firmware contrib
EOF
        ;;
    3)
        echo "Module 3: Reconfiguring locales and timezone"
        dpkg-reconfigure locales tzdata keyboard-configuration console-setup
        ;;
    4)
        echo "Module 4: Configuring DKMS ZFS"
        echo "REMAKE_INITRD=yes" > /etc/dkms/zfs.conf
        ;;
    5)
        echo "Module 5: Enabling ZFS services"
        systemctl enable zfs.target
        systemctl enable zfs-import-cache
        systemctl enable zfs-mount
        systemctl enable zfs-import.target
        systemctl enable systemd-resolved
        systemctl enable systemd-networkd
        ;;
    6)
        echo "Module 6: Updating initramfs"
        update-initramfs -c -k all
        ;;
    7)
        echo "Module 7: Setting ZFSBootMenu commandline"
        zfs set org.zfsbootmenu:commandline="quiet" zroot/ROOT
        ;;
    8)
        echo "Module 8: Formatting boot partition"
        mkfs.vfat -F32 "$BOOT_DEVICE"
        ;;
    9)
        echo "Module 9: Configuring fstab and mounting boot"
        cat << EOF >> /etc/fstab
$( blkid | grep "$BOOT_DEVICE" | cut -d ' ' -f 2 ) /boot/efi vfat defaults 0 0
EOF
        mkdir -p /boot/efi
        mount /boot/efi
        ;;
    10)
        echo "Module 10: Mounting efivarfs"
        mount -t efivarfs efivarfs /sys/firmware/efi/efivars
        ;;
    11)
        echo "Module 11: Creating ZFSBootMenu backup boot entry"
        mkdir -p /boot/efi/zbm
        cp /tmp/zbm/VMLINUZ.EFI /boot/efi/zbm/VMLINUZ-BACKUP.EFI
        efibootmgr -c -d "$BOOT_DISK" -p "$BOOT_PART" \
          -L "ZFSBootMenu (Backup)" \
          -l '\zbm\VMLINUZ-BACKUP.EFI'
        ;;
    12)
        echo "Module 12: Creating ZFSBootMenu main boot entry"
        mkdir -p /boot/efi/zbm
        cp /tmp/zbm/VMLINUZ.EFI /boot/efi/zbm/VMLINUZ.EFI
        efibootmgr -c -d "$BOOT_DISK" -p "$BOOT_PART" \
          -L "ZFSBootMenu" \
          -l '\zbm\VMLINUZ.EFI'
        ;;
    13)
        echo "Module 13: Setting root password and cleaning APT proxy"
        echo 'root:root' | chpasswd
        sed -i 's|172\.17\.0\.2:3142/||g' /etc/apt/sources.list
        ;;
    *)
        echo "Error: Invalid module number. Please use 1-13."
        exit 1
        ;;
esac

echo "Module $MODULE completed successfully."