import os
import shutil
import tarfile
import urllib.request
from pathlib import Path

from .logger import get_logger
from .paths import ZFS_EFI_URL, ZFS_KERNEL_URL


def ensure_zfs_vmlinuz_efi():
    """
    Ensure VMLINUZ.EFI exists in conf/cdrom-files/zbm/ directory.
    If missing, download it from https://get.zfsbootmenu.org/latest.EFI
    and rename it to VMLINUZ.EFI.
    
    Returns:
        bool: True if file exists or was successfully downloaded, False otherwise
    """
    logger = get_logger('vmlinuz_efi', 'vmlinuz_efi.log')
    
    target_path = Path('conf/cdrom-files/zbm/VMLINUZ.EFI')
    target_dir = target_path.parent
    
    if target_path.exists():
        logger.info(f'VMLINUZ.EFI already exists at {target_path}')
        return True
    
    logger.info('VMLINUZ.EFI not found, downloading from https://get.zfsbootmenu.org/latest.EFI')
    
    try:
        target_dir.mkdir(parents=True, exist_ok=True)
        
        download_url = ZFS_EFI_URL
        temp_file = target_path.with_suffix('.tmp')
        
        logger.info(f'Downloading {download_url} to {temp_file}')
        
        with urllib.request.urlopen(download_url) as response:
            with open(temp_file, 'wb') as f:
                shutil.copyfileobj(response, f)
        
        temp_file.rename(target_path)
        logger.info(f'Successfully downloaded and renamed to {target_path}')
        return True
        
    except Exception as e:
        logger.error(f'Failed to download VMLINUZ.EFI: {e}')
        
        temp_file = target_path.with_suffix('.tmp')
        if temp_file.exists():
            temp_file.unlink()
            
        return False


def ensure_zfs_kernel_files():
    """
    Ensure vmlinuz-bootmenu and initramfs-bootmenu.img exist in conf/cdrom-files/zbm/ directory.
    If missing, download from ZFS_KERNEL_URL (tar.gz) and extract the required files.
    
    Returns:
        bool: True if files exist or were successfully downloaded/extracted, False otherwise
    """
    logger = get_logger('zfs_kernel', 'zfs_kernel.log')
    
    target_dir = Path('conf/cdrom-files/zbm')
    vmlinuz_file = target_dir / 'vmlinuz-bootmenu'
    initramfs_file = target_dir / 'initramfs-bootmenu.img'
    
    if vmlinuz_file.exists() and initramfs_file.exists():
        logger.info('ZFS kernel files already exist')
        return True
    
    logger.info(f'Missing ZFS kernel files, downloading from {ZFS_KERNEL_URL}')
    
    try:
        target_dir.mkdir(parents=True, exist_ok=True)
        
        temp_tar = target_dir / 'zfs_kernel_temp.tar.gz'
        
        logger.info(f'Downloading {ZFS_KERNEL_URL} to {temp_tar}')
        
        with urllib.request.urlopen(ZFS_KERNEL_URL) as response:
            with open(temp_tar, 'wb') as f:
                shutil.copyfileobj(response, f)
        
        logger.info('Extracting required files from archive')
        
        with tarfile.open(temp_tar, 'r:gz') as tar:
            # Extract only the required files
            required_files = []
            for member in tar.getmembers():
                if member.name.endswith('vmlinuz-bootmenu') or member.name.endswith('initramfs-bootmenu.img'):
                    required_files.append(member)
            
            if not required_files:
                raise ValueError('Required files not found in archive')
            
            for member in required_files:
                # Extract to target directory with simplified name
                if member.name.endswith('vmlinuz-bootmenu'):
                    member.name = 'vmlinuz-bootmenu'
                elif member.name.endswith('initramfs-bootmenu.img'):
                    member.name = 'initramfs-bootmenu.img'
                
                tar.extract(member, target_dir)
        
        temp_tar.unlink()
        logger.info('Successfully extracted ZFS kernel files')
        return True
        
    except Exception as e:
        logger.error(f'Failed to download/extract ZFS kernel files: {e}')
        
        temp_tar = target_dir / 'zfs_kernel_temp.tar.gz'
        if temp_tar.exists():
            temp_tar.unlink()
            
        return False