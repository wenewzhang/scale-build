# -*- coding=utf-8 -*-
"""
Internationalization (i18n) module for TrueNAS Install
支持多语言切换，目前支持英语和中文
"""

from typing import Dict

# 当前语言设置
_current_language = "en"

# 翻译字典
TRANSLATIONS: Dict[str, Dict[str, str]] = {
    "en": {
        # 安装进度消息 - 用户通过 write_progress 看到的消息
        "creating_dataset": "Creating dataset",
        "installation_completed": "Installation completed successfully",
        "upgrade_completed": "Upgrade completed successfully",
    },
    "zh": {
        # 安装进度消息 - 用户通过 write_progress 看到的消息
        "creating_dataset": "正在创建数据集",
        "installation_completed": "安装成功完成",
        "upgrade_completed": "升级成功完成",
    }
}


def set_language(lang: str) -> bool:
    """
    设置当前语言
    
    Args:
        lang: 语言代码，如 "en", "zh"
    
    Returns:
        是否设置成功
    """
    global _current_language
    if lang in TRANSLATIONS:
        _current_language = lang
        return True
    return False


def get_language() -> str:
    """获取当前语言代码"""
    return _current_language


def get_available_languages() -> Dict[str, str]:
    """获取可用语言列表"""
    return {
        "en": "English",
        "zh": "中文 (Chinese)",
    }


def _(key: str, **kwargs) -> str:
    """
    翻译函数
    
    Args:
        key: 翻译键
        **kwargs: 格式化参数
    
    Returns:
        翻译后的字符串
    """
    # 获取当前语言的翻译
    translation = TRANSLATIONS.get(_current_language, TRANSLATIONS["en"])
    
    # 获取翻译文本，如果不存在则返回键名
    text = translation.get(key, TRANSLATIONS["en"].get(key, key))
    
    # 格式化参数
    if kwargs:
        try:
            text = text.format(**kwargs)
        except (KeyError, ValueError):
            # 如果格式化失败，返回原始文本
            pass
    
    return text
