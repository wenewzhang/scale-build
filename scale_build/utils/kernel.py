import glob
import os


def get_kernel_version(rootfs_path):
    return glob.glob(os.path.join(rootfs_path, 'boot/vmlinuz-*'))[0].split('/')[-1][len('vmlinuz-'):]
