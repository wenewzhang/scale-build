#!/bin/bash

# Get the step number from the first argument
STEP=$1

# Basic usage check
if [ -z "$STEP" ]; then
    echo "Usage: $0 [1-7] [additional arguments for step 6]"
    echo "Steps:"
    echo "  1: Enable ZFS boot-pool import service"
    echo "  2: Purge os-prober"
    echo "  3: Probe /boot path"
    echo "  4: Update Initramfs (all kernels)"
    echo "  5: Install GRUB (EFI mode)"
    echo "  6: Install GRUB to specific disk (Requires 2 arguments: e.g.,<6> <disk>)"
    echo "  7: Update GRUB configuration"
    exit 1
fi

case $STEP in
    1)
        echo ">>> [Step 1] Enabling zfs-import-bpool.service..."
        systemctl enable zfs-import-bpool.service
        ;;
    2)
        echo ">>> [Step 2] Purging os-prober..."
        apt purge --yes os-prober
        ;;
    3)
        echo ">>> [Step 3] Running grub-probe on /boot..."
        grub-probe /boot
        ;;
    4)
        echo ">>> [Step 4] Updating Initramfs for all kernels..."
        update-initramfs -c -k all
        ;;
    5)
        echo ">>> [Step 5] Installing GRUB for UEFI (x86_64-efi)..."
        DISK_PARAM=$2
        
        if [ -z "$DISK_PARAM" ]; then
            echo "Error: Step 6 requires two parameters (e.g., $0 5 /dev/sda2)"
            exit 1
        fi
        mkdosfs -F 32 -s 1 -n EFI ${DISK_PARAM}
        mkdir -p /boot/efi
        echo /dev/disk/by-uuid/$(blkid -s UUID -o value ${DISK_PARAM}) \
        /boot/efi vfat defaults 0 0 >> /etc/fstab
        mount /boot/efi
        echo "UEFI has been successfully installed on: $DISK_PARAM"        
        grub-install --target=x86_64-efi --efi-directory=/boot/efi \
                     --bootloader-id=debian --recheck --no-floppy
        ;;
    6)
        # Check if two additional parameters are provided for this step
        # Usage: ./script.sh 6 /dev/sda
        DISK_PARAM=$2
        
        if [ -z "$DISK_PARAM" ]; then
            echo "Error: Step 6 requires two parameters (e.g., $0 6 /dev/sda)"
            exit 1
        fi
        
        echo ">>> [Step 6] Installing GRUB to $DISK_PARAM with option"
        grub-install "$DISK_PARAM" 
        ;;
    7)
        echo ">>> [Step 7] Updating GRUB configuration..."
        update-grub
        ;;
    *)
        echo "Invalid Step: $STEP. Please use a number between 1 and 7."
        exit 1
        ;;
esac

echo ">>> Step $STEP completed successfully."