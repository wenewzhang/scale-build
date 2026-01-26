#!/bin/bash
MNT="$1"
DELAY=1
# Define mount points to unmount, from deepest to top-level
targets=(
    "${MNT}/dev/pts"
    "${MNT}/dev"
    "${MNT}/sys"
    "${MNT}/proc"
    "${MNT}"
)

# Keep retrying until all targets are unmounted
while true; do
    all_unmounted=true

    for target in "${targets[@]}"; do
        # Check if the target is still a mount point
        if mountpoint -q "$target" 2>/dev/null; then
            echo "Attempting to unmount: $target"
            umount "$target" 2>/dev/null
            sleep "$DELAY"
            # Verify if it's still mounted after umount attempt
            if mountpoint -q "$target" 2>/dev/null; then
                all_unmounted=false  # Still mounted → not done yet
            fi
        fi
    done

    if [ "$all_unmounted" = true ]; then
        echo "✅ All mount points successfully unmounted."
        break
    fi

    echo "Some mount points are still busy. Retrying in $DELAY second(s)..."
    sleep "$DELAY"
done