#!/bin/bash

set -euo pipefail

# === Argument check ===
if [ $# -ne 1 ]; then
    echo "Usage: $0 <disk device>" >&2
    echo "Example: $0 /dev/disk/by-id/ata-WDC_..." >&2
    exit 1
fi

DISK="$1"

# === Verify ESP partition exists ===
ESP_PART="${DISK}-part2"

if [ ! -b "$ESP_PART" ]; then
    echo "Error: ESP partition '$ESP_PART' does not exist! Please create it first using sgdisk." >&2
    exit 1
fi

# === Format as FAT32 ===
echo "Formatting ESP partition ($ESP_PART) as FAT32..."
mkdosfs -F 32 -s 1 -n EFI "$ESP_PART" >/dev/null

# === Get UUID (more reliable) ===
ESP_UUID=$(blkid -s UUID -o value "$ESP_PART")

if [ -z "$ESP_UUID" ]; then
    echo "Error: Failed to retrieve UUID for ESP partition" >&2
    exit 1
fi

# === Handle mount point (assuming system is being installed under /mnt) ===
# In a Live CD installation environment, the target system's /boot/efi is typically /mnt/boot/efi
TARGET_BOOT_EFI="/mnt/boot/efi"

# Create directory (-p avoids error if it already exists)
mkdir -p "$TARGET_BOOT_EFI"

# === Write to target system's /etc/fstab (NOT the current live system!) ===
FSTAB="/mnt/etc/fstab"

# Avoid duplicate entries (optional)
if ! grep -q "UUID=$ESP_UUID" "$FSTAB" 2>/dev/null; then
    echo "UUID=$ESP_UUID /boot/efi vfat defaults,uid=0,gid=0,umask=077,shortname=winnt 0 2" >> "$FSTAB"
    echo "✅Added entry to /etc/fstab"
else
    echo "ESP entry already exists in /etc/fstab, skipping"
fi

# === Mount to target system directory ===
if ! mountpoint -q "$TARGET_BOOT_EFI"; then
    mount "$ESP_PART" "$TARGET_BOOT_EFI"
    echo "ESP mounted at $TARGET_BOOT_EFI"
else
    echo "$TARGET_BOOT_EFI is already mounted"
fi