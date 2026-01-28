#!/usr/bin/env python3
import sys
import os

sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..', '..'))

from scale_build.utils.vmlinuz_efi import ensure_zfs_vmlinuz_efi, ensure_zfs_kernel_files

# mkdir -p /tmp/logs && export BUILDER_DIR=/tmp && cd /home/jimmy/Documents/goSeasNG/sl/truenas/scale-build && python scale_build/tests/call_vmlinuz_efi.py
def main():
    print("Calling ensure_zfs_vmlinuz_efi...")
    ensure_zfs_vmlinuz_efi()
    ensure_zfs_kernel_files()
    print("Function call completed.")

if __name__ == "__main__":
    main()