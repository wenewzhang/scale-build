import os
import shutil
import tempfile
import unittest
import json
from scale_build.packages.package import Package
from scale_build.utils.package import get_packages

class TestPackageBinaryRealFile(unittest.TestCase):

    def setUp(self):
        print(f"setUp")
        # 1. 创建临时目录模拟源码根目录
        self.test_dir = tempfile.mkdtemp()
        self.source_dir = os.path.join(self.test_dir, "truenas_installer")
        os.makedirs(os.path.join(self.source_dir, "debian"), exist_ok=True)

        # 2. 将上传的 control 内容写入临时位置
        # 注意：这里假设当前目录下已经有名为 'control' 的文件（即你上传的文件）
        control_content = """Source: truenas_installer
Section: admin
Priority: optional
Maintainer: Vladimir Vinogradenko <vladimirv@ixsystems.com>
Build-Depends: debhelper-compat (= 12),
               dh-python,
               python3-all
Standards-Version: 4.4.0

Package: python3-truenas_installer
Architecture: all
Depends: ${misc:Depends},
         ${python3:Depends},
         avahi-daemon,
         openzfs,
         util-linux
Description: TrueNAS Installer
"""
        with open(os.path.join(self.source_dir, "debian/control"), "w") as f:
            f.write(control_content)

        # 3. 实例化 Package
        # 注意：我们需要手动指定 source_path 逻辑中依赖的全局变量或环境
        self.pkg = Package(
            name="truenas_installer",
            branch="master",
            repo="https://github.com/truenas/installer.git"
        )

    def tearDown(self):
        # 清理临时目录
        print(f"tearDown")
        shutil.rmtree(self.test_dir)

    def test_binary_packages_with_real_control(self):
        desired_packages=None
        binary_packages = {}
        desired_packages = desired_packages or []
        packages_list = get_packages()
        packages = {}
        for package in packages_list:
            if not package.exists:
                print(f'Missing sources for {package.name},  did you forget to run "make checkout" ?')

            packages[package.name] = package
            for binary_package in package.binary_packages:
                binary_packages[binary_package.name] = binary_package
                print(f"binary_package:%r",binary_package)
        print(f"test_binary_packages_with_real_control:%r",binary_packages)


if __name__ == '__main__':
    unittest.main()