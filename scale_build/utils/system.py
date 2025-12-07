import hashlib
from functools import cache

REQUIRED_RAM_GB = 16 * (1024 ** 3)

__all__ = ("has_low_ram",)


@cache
def has_low_ram():
    with open('/proc/meminfo') as f:
        for line in filter(lambda x: 'MemTotal' in x, f):
            return int(line.split()[1]) * 1024 < REQUIRED_RAM_GB


def calculate_sha256(file_path, block_size=65536):
    """Calculate SHA256 hash of a file (chunked for large files)"""
    sha256 = hashlib.sha256()
    try:
        with open(file_path, 'rb') as f:
            while chunk := f.read(block_size):  # Python 3.8+ walrus operator
                sha256.update(chunk)
        return sha256.hexdigest()
    except FileNotFoundError:
        print(f"Error: File {file_path} not found")
        return None
    except Exception as e:
        print(f"Error reading file: {e}")
        return None
