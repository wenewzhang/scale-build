import os
from typing import Optional, TextIO


class SimpleWriter:
    def __init__(self, file_path: str = "/var/log/zuti.sh"):
        self.file_path = file_path
        self._ensure_directory_exists()
        self.writeln('#!/bin/bash')
    
    def _ensure_directory_exists(self):
        """确保文件目录存在"""
        try:
            directory = os.path.dirname(self.file_path)
            if directory:
                os.makedirs(directory, mode=0o755, exist_ok=True)
        except (OSError, PermissionError):
            # 如果无法创建目录，静默处理
            pass
    
    def _open_file(self, mode: str = 'a') -> Optional[TextIO]:
        """安全地打开文件"""
        try:
            return open(self.file_path, mode, encoding='utf-8')
        except (OSError, PermissionError):
            # 如果无法打开文件，静默处理
            return None
    
    def write(self, text: str):
        """写入文本到文件（不自动换行）"""
        f = self._open_file('a')
        if f:
            f.write(text)
            f.flush()
            f.close()
    
    def writeln(self, text: str):
        """写入一行文本到文件（自动添加换行符）"""
        f = self._open_file('a')
        if f:
            f.write(text + '\n')
            f.flush()
            f.close()
    
    def clear(self):
        """清空文件内容"""
        f = self._open_file('w')
        if f:
            f.flush()
            f.close()
    
    def __enter__(self):
        """支持上下文管理器"""
        return self
    
    def __exit__(self, exc_type, exc_val, exc_tb):
        """支持上下文管理器"""
        pass


# 全局实例，可以直接使用
writer = SimpleWriter()