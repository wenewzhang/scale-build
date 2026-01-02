import logging
import os
import sys

# 建议在 logger.py 顶层定义格式
LOG_FORMAT = '%(asctime)s %(name)s[%(process)d]: %(levelname)s - %(message)s'

def get_file_logger(name="zuti", log_file="/var/log/zuti.log", level=logging.INFO):
    logger = logging.getLogger(name)
    if logger.handlers:
        return logger

    logger.setLevel(level)
    
    # 尝试创建目录
    log_dir = os.path.dirname(log_file)
    try:
        os.makedirs(log_dir, mode=0o755, exist_ok=True)
        # 尝试创建 FileHandler
        handler = logging.FileHandler(log_file, mode='a', encoding='utf-8')
        # 尝试设置文件权限
        try:
            os.chmod(log_file, 0o644)
        except OSError:
            pass # 无法改权限但不影响写入，通常可忽略
            
    except (OSError, PermissionError):
        # 彻底回退到 stderr
        handler = logging.StreamHandler(sys.stderr)
        print(f"Warning: Cannot write to {log_file}, logging to stderr instead.", file=sys.stderr)

    formatter = logging.Formatter(LOG_FORMAT, datefmt='%m%d %H%M%S')
    handler.setFormatter(formatter)
    logger.addHandler(handler)
    
    return logger

# 在 logger.py 末尾直接初始化一个全局实例
logger = get_file_logger(level=logging.DEBUG)