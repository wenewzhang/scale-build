#!/bin/bash
MNT="$1"
DELAY=1

while ! umount -R "$MNT" 2>/dev/null; do
    echo "Unmount failed. Retrying in $DELAY second(s)..."
    sleep "$DELAY"
done

echo "✅ Recursive unmount completed successfully."
