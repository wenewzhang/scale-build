import glob
import hashlib
import itertools
import os
import shutil
import tarfile
import tempfile
import time
import json

import requests

from scale_build.exceptions import CallError
from scale_build.utils.manifest import get_apt_repos, get_manifest
from scale_build.utils.run import run
from scale_build.utils.paths import CD_DIR, CD_FILES_DIR, CDROM_FILES_DIR, CHROOT_BASEDIR, CONF_GRUB, PKG_DIR, RELEASE_DIR, TMP_DIR
from scale_build.utils.paths import BUILDER_DIR
from scale_build.utils.vmlinuz_efi import ensure_zfs_vmlinuz_efi, ensure_zfs_kernel_files
from scale_build.config import TRUENAS_VENDOR
from scale_build.config import PRESERVE_ISO

from .bootstrap import umount_chroot_basedir
from .manifest import get_image_version, update_file_path, get_version
from .utils import run_in_chroot
import logging

logger = logging.getLogger(__name__)

def install_iso_packages():
    try:
        install_iso_packages_impl()
    finally:
        umount_chroot_basedir()


def install_iso_packages_impl():
    run_in_chroot(['apt', 'update'])

    with open(f"{CHROOT_BASEDIR}/etc/resolv.conf") as f:
        resolv_conf = f.read()

    # echo "/dev/disk/by-label/TRUENAS / iso9660 loop 0 0" > ${CHROOT_BASEDIR}/etc/fstab
    for package in get_manifest()['iso-packages']:
        run_in_chroot(['apt', 'install', '-y', package])

    # We want to make sure that truenas-installer service is enabled
    run_in_chroot(['systemctl', 'enable', 'truenas-installer.service'])

    # Installing systemd-resolved breaks existing resolv.conf
    os.unlink(f"{CHROOT_BASEDIR}/etc/resolv.conf")
    with open(f"{CHROOT_BASEDIR}/etc/resolv.conf", "w") as f:
        f.write(resolv_conf)

    # Inject vendor name into grub.cfg
    with open(CONF_GRUB, 'r') as f:
        grub_cfg = f.read()
    grub_cfg = grub_cfg.replace('$vendor', TRUENAS_VENDOR or 'TrueNAS SCALE')

    os.makedirs(os.path.join(CHROOT_BASEDIR, 'boot/grub'), exist_ok=True)
    with open(os.path.join(CHROOT_BASEDIR, 'boot/grub/grub.cfg'), 'w') as f:
        f.write(grub_cfg)


def make_iso_file():
    if not PRESERVE_ISO:
        for f in glob.glob(os.path.join(RELEASE_DIR, '*.iso*')):
            os.unlink(f)

    # Set default PW to root
    run(fr'chroot {CHROOT_BASEDIR} /bin/bash -c "echo -e \"root\nroot\" | passwd root"', shell=True)

    # Bring up network for the installer
    run(f'chroot {CHROOT_BASEDIR} systemctl enable systemd-networkd systemd-resolved', shell=True)

    # Create /etc/version
    with open(os.path.join(CHROOT_BASEDIR, 'etc/version'), 'w') as f:
        f.write(get_image_version())

    # Set /etc/hostname so that hostname of builder is not advertised
    with open(os.path.join(CHROOT_BASEDIR, 'etc/hostname'), 'w') as f:
        f.write('truenas-installer.local')

    os.makedirs(os.path.join(CHROOT_BASEDIR, 'data'))
    if TRUENAS_VENDOR:
        with open(os.path.join(CHROOT_BASEDIR, 'data/.vendor'), 'w') as f:
            f.write(json.dumps({'name': TRUENAS_VENDOR}))

    # Copy the CD files
    run(f'rsync -aKv {CD_FILES_DIR}/ {CHROOT_BASEDIR}/', shell=True)

    # Create the CD assembly dir
    if os.path.exists(CD_DIR):
        shutil.rmtree(CD_DIR)
    os.makedirs(CD_DIR, exist_ok=True)

    # Let's make squashfs now while pruning away the fat
    tmp_truenas_path = os.path.join(TMP_DIR, 'truenas.squashfs')
    with tempfile.NamedTemporaryFile(mode='w') as exclude_file:
        exclude_file.write('\n'.join(pruning_cd_basedir_contents()))
        exclude_file.flush()

        run(['mksquashfs', CHROOT_BASEDIR, tmp_truenas_path, '-comp', 'gzip', '-ef', exclude_file.name])

    os.makedirs(os.path.join(CD_DIR, 'live'), exist_ok=True)
    shutil.move(tmp_truenas_path, os.path.join(CD_DIR, 'live/filesystem.squashfs'))

    # Copy over boot and kernel before rolling CD
    shutil.copytree(os.path.join(CHROOT_BASEDIR, 'boot'), os.path.join(CD_DIR, 'boot'))
    # Dereference /initrd.img and /vmlinuz so this ISO can be re-written to a FAT32 USB stick using Windows tools
    shutil.copy(os.path.join(CHROOT_BASEDIR, 'initrd.img'), CD_DIR)
    shutil.copy(os.path.join(CHROOT_BASEDIR, 'vmlinuz'), CD_DIR)
    for f in itertools.chain(
        glob.glob(os.path.join(CD_DIR, 'boot/initrd.img-*')),
        glob.glob(os.path.join(CD_DIR, 'boot/vmlinuz-*')),
    ):
        os.unlink(f)
    
    shutil.copy(update_file_path(get_version()), os.path.join(CD_DIR, 'TrueNAS-SCALE.update'))
    os.makedirs(os.path.join(CHROOT_BASEDIR, RELEASE_DIR), exist_ok=True)
    os.makedirs(os.path.join(CHROOT_BASEDIR, CD_DIR), exist_ok=True)

    # Debian GRUB EFI image probes for `.disk/info` file to identify a device/partition
    # to load config file from.
    os.makedirs(os.path.join(CD_DIR, '.disk'), exist_ok=True)
    with open(os.path.join(CD_DIR, '.disk/info'), 'w') as f:
        pass

    try:
        run(['mount', '--bind', RELEASE_DIR, os.path.join(CHROOT_BASEDIR, RELEASE_DIR)])
        run(['mount', '--bind', CD_DIR, os.path.join(CHROOT_BASEDIR, CD_DIR)])
        run(['mount', '--bind', PKG_DIR, os.path.join(CHROOT_BASEDIR, 'packages')])
        run_in_chroot(['apt-get', 'update'], check=False)
        run_in_chroot([
            'apt-get', 'install', '-y', 'grub-common', 'grub2-common', 'grub-efi-amd64-bin',
            'grub-pc-bin', 'mtools', 'xorriso'
        ])

        ensure_zfs_vmlinuz_efi()
        ensure_zfs_kernel_files()
        os.makedirs(os.path.join(CD_DIR, 'scripts'), exist_ok=True)
        run(f'rsync -aKv {CDROM_FILES_DIR}/ {CD_DIR}/scripts/', shell=True)
        # Debian GRUB EFI searches for GRUB config in a different place
        os.makedirs(os.path.join(CD_DIR, 'EFI/debian'), exist_ok=True)
        shutil.copy(os.path.join(CHROOT_BASEDIR, 'boot/grub/grub.cfg'), os.path.join(CD_DIR, 'EFI/debian/grub.cfg'))
        os.makedirs(os.path.join(CD_DIR, 'EFI/debian/fonts'), exist_ok=True)
        shutil.copy(os.path.join(CHROOT_BASEDIR, 'usr/share/grub/unicode.pf2'),
                    os.path.join(CD_DIR, 'EFI/debian/fonts/unicode.pf2'))

        iso = os.path.join(RELEASE_DIR, f'TrueNAS-SCALE-{get_image_version(vendor=TRUENAS_VENDOR)}.iso')

        # Default grub EFI image does not support `search` command which we need to make TrueNAS ISO working in
        # Rufus "ISO Image mode".
        # Let's use pre-built Debian GRUB EFI image that the official Debian ISO installer uses.
        with tempfile.NamedTemporaryFile(dir=RELEASE_DIR) as efi_img:
            with tempfile.NamedTemporaryFile(suffix='.tar.gz') as f:
                apt_repos = get_apt_repos(check_custom=True)
                r = requests.get(
                    f'{apt_repos["url"]}dists/{apt_repos["distribution"]}/main/installer-amd64/current/images/cdrom/'
                    'debian-cd_info.tar.gz',
                    timeout=10,
                    stream=True,
                )
                r.raise_for_status()
                shutil.copyfileobj(r.raw, f)
                f.flush()

                with tarfile.open(f.name) as tf:
                    shutil.copyfileobj(tf.extractfile('./grub/efi.img'), efi_img)

            efi_img.flush()

            run_in_chroot([
                'grub-mkrescue',
                '-o', iso,
                '--efi-boot-part', os.path.join(
                    RELEASE_DIR, os.path.relpath(efi_img.name, os.path.abspath(RELEASE_DIR))
                ),
                CD_DIR,
            ])

        # lo = run(['losetup', '-f'], log=False).stdout.strip()
        # run(['losetup', '-P', lo, iso])
        # try:
        #     with tempfile.TemporaryDirectory() as td:
        #         for i in itertools.count():
        #             try:
        #                 run(['mount', f'{lo}p2', td])
        #                 break
        #             except CallError:
        #                 if i >= 10:
        #                     raise
        #                 else:
        #                     # losetup --partscan instructs the kernel to scan the partition table and add separate
        #                     # partition devices for each of the partitions it finds. However, this operation is
        #                     # asynchronous which means losetup will return before all partition devices have been
        #                     # initialized. This can result in a race condition where we try to access a partition device
        #                     # before it's been initialized by the kernel.
        #                     time.sleep(1)

        #         try:
        #             grub_cfg_path = os.path.join(td, 'EFI/debian/grub.cfg')
        #             with open(grub_cfg_path) as f:
        #                 grub_cfg = f.read()

        #             substr = 'source $prefix/x86_64-efi/grub.cfg'
        #             if substr not in grub_cfg:
        #                 raise ValueError(f'Invalid grub.cfg:\n{grub_cfg}')

        #             grub_cfg = grub_cfg.replace(substr, 'source $prefix/grub.cfg')

        #             with open(grub_cfg_path, 'w') as f:
        #                 f.write(grub_cfg)
        #         finally:
        #             run(['umount', td])
        # finally:
        #     run(['losetup', '-d', lo])
    finally:
        run(['umount', '-f', os.path.join(CHROOT_BASEDIR, CD_DIR)])
        run(['umount', '-f', os.path.join(CHROOT_BASEDIR, RELEASE_DIR)])
        run(['umount', '-f', os.path.join(CHROOT_BASEDIR, 'packages')])

    image_version = get_image_version(vendor=TRUENAS_VENDOR)
    with open(os.path.join(RELEASE_DIR, f'TrueNAS-SCALE-{image_version}.iso.sha256'), 'w') as f:
        with open(os.path.join(RELEASE_DIR, f'TrueNAS-SCALE-{image_version}.iso'), 'rb') as sf:
            f.write(hashlib.file_digest(sf, 'sha256').hexdigest())


def pruning_cd_basedir_contents():
    return itertools.chain(
        [
            'var/cache/apt',
            'var/lib/apt',
            'usr/share/doc',
            'usr/share/man',
            'etc/resolv.conf',
        ], map(
            lambda path: path.removeprefix(f'{CHROOT_BASEDIR}/'),
            glob.glob(os.path.join(CHROOT_BASEDIR, 'lib/modules/*truenas/kernel/sound'))
        )
    )



# install sudo pacman -S mtools xorriso
def pack_iso(iso_dir):
    with tempfile.NamedTemporaryFile(dir=TMP_DIR) as efi_img:
        with tempfile.NamedTemporaryFile(suffix='.tar.gz') as f:
            apt_repos = get_apt_repos(check_custom=True)
            r = requests.get(
                f'{apt_repos["url"]}dists/{apt_repos["distribution"]}/main/installer-amd64/current/images/cdrom/'
                'debian-cd_info.tar.gz',
                timeout=10,
                stream=True,
            )
            r.raise_for_status()
            shutil.copyfileobj(r.raw, f)
            f.flush()

            with tarfile.open(f.name) as tf:
                shutil.copyfileobj(tf.extractfile('./grub/efi.img'), efi_img)

            efi_img.flush()

            # copy the load TrueNAS-SCALE.update script for debug
            shutil.copy(os.path.join(CDROM_FILES_DIR, 'load-update.sh'), iso_dir)
            run(["chmod", "500", f"{iso_dir}/load-update.sh"])
            run([
            'grub-mkrescue',
            '-o', os.path.join(TMP_DIR, 'TrueNAS-SCALE.iso'),
            '--efi-boot-part',
            os.path.join(
                    TMP_DIR, os.path.relpath(efi_img.name, os.path.abspath(TMP_DIR))
                ),
            iso_dir
            ])
            logger.info("get url:%s",f'{apt_repos["url"]}dists/{apt_repos["distribution"]}/main/installer-amd64/current/images/cdrom/'
                'debian-cd_info.tar.gz')
            logger.info('Packing %s to %s  success', iso_dir, os.path.join(TMP_DIR, 'TrueNAS-SCALE.iso'))

def unpack_iso(iso_path):
    logger.info('Unpacking %s', iso_path)
    isotmp="/tmp/iso_tmp"
    if os.path.exists(isotmp):
        shutil.rmtree(isotmp)

    os.makedirs(isotmp, exist_ok=True)    

    run([
    'mount',
    '-o',
    'loop', 
    iso_path,
    isotmp])

    run([
    'cp',
    '-raf',
    isotmp,
    os.path.join(TMP_DIR, 'iso_contents')
    ])
    logger.info('Unpacking %s to %s  success', iso_path, os.path.join(TMP_DIR, 'iso_contents'))
    
def replace_installation_files(update_path):
    logger.info('Replacing installation files')
    update_dest = os.path.join(TMP_DIR, "tmpupdate")

    if not os.path.exists(update_path):
        raise RuntimeError(f"Update file {update_path} not exists")
    
    if os.path.exists(update_dest):
        shutil.rmtree(update_dest)

    os.makedirs(update_dest)
    run(["unsquashfs", "-dest", update_dest, update_path])
    
    dest_i = os.path.join(update_dest, 'truenas_install')
    if os.path.exists(dest_i):
        shutil.rmtree(dest_i)

    os.unlink(update_path)

    shutil.copytree(
        os.path.join(BUILDER_DIR, 'truenas_install'),
        dest_i,
    )
    run(["mksquashfs", update_dest, update_path, "-comp", "gzip"])

    logger.info('Replacing installation files success: %s', update_path)

def patch_installation_files(update_path):
    logger.info('Patching installation files')
    update_dest = os.path.join(TMP_DIR, "tmpupdate")

    if not os.path.exists(update_path):
        raise RuntimeError(f"Update file {update_path} not exists")
    
    if os.path.exists(update_dest):
        shutil.rmtree(update_dest)

    os.makedirs(update_dest)
    run(["unsquashfs", "-dest", update_dest, update_path])
    
    dest_i = os.path.join(update_dest, 'truenas_install')
    patch_i = os.path.join(BUILDER_DIR, 'truenas_install/zuti-logger-for-installer.patch')

    os.unlink(update_path)

    run(["sh", "-c",f'patch -p2 -d {dest_i} < {patch_i}'])

    run(["mksquashfs", update_dest, update_path, "-comp", "gzip"])

    logger.info('Patch installation files success: %s', update_path)    