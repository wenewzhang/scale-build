#!/bin/bash
if [ $# -ne 1 ]; then
    echo "Usage: $0 </mnt>"
    echo "Example: $0 /mnt"
    exit 1
fi

MNT="$1"

mkdir -p "$MNT/proc" "$MNT/sys" "$MNT/dev" "$MNT/dev/pts"

mount -t proc proc ${MNT}/proc
mount -t sysfs sys ${MNT}/sys
mount -B /dev ${MNT}/dev
mount -t devpts pts ${MNT}/dev/pts
chroot ${MNT}

./test-umount.sh ${MNT}
# DELAY=1
# sleep "$DELAY"
# umount ${MNT}/dev/pts
# sleep "$DELAY"
# umount ${MNT}/dev
# sleep "$DELAY"
# umount ${MNT}/sys
# sleep "$DELAY"
# umount ${MNT}/proc
# sleep "$DELAY"

# umount ${MNT}