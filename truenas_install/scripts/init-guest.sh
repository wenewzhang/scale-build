#!/bin/bash
if [ $# -ne 1 ]; then
    echo "Usage: $0 <path>"
    echo "Example: $0 /mnt"
    exit 1
fi

RPATH="$1"

mkdir -p "${RPATH}/tmp"
chmod +x "${RPATH}/usr/bin/dpkg"
chmod +x "${RPATH}/usr/bin/apt"
cp guest* "${RPATH}/tmp/"
cp zfs-import-bpool.service "${RPATH}/etc/systemd/system/"
