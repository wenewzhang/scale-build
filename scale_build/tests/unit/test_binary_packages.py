import os
import shutil
import tempfile
import unittest
import json
from scale_build.packages.package import Package

class TestPackageBinaryRealFile(unittest.TestCase):

    def setUp(self):
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
        shutil.rmtree(self.test_dir)

    def test_binary_packages_with_real_control(self):
        """
        通过修改 SOURCES_DIR 指向临时目录，实现无 Mock 测试
        """
        from scale_build.utils import paths
        
        # 临时覆盖全局变量，让 Package.source_path 指向我们的临时目录
        original_sources_dir = paths.SOURCES_DIR
        paths.SOURCES_DIR = self.test_dir
        
        try:
            # 确保脚本存在。如果当前环境没有 ./scripts/parse_deps.pl，测试会失败
            # 这是一个“集成测试”，验证 Python 与 Perl 脚本的真实交互
            if not os.path.exists('./scripts/parse_deps.pl'):
                self.skipTest("当前路径缺少 ./scripts/parse_deps.pl，无法进行无 Mock 测试")

            bin_pkgs = self.pkg.binary_packages

            # 验证解析结果
            self.assertGreater(len(bin_pkgs), 0, "应该至少解析出一个二进制包")
            
            installer_pkg = next(p for p in bin_pkgs if p.name == "python3-truenas_installer")
            
            # 验证依赖项是否被正确清理（去掉了版本号和 ${...} 变量）
            # 根据 control 内容，'openzfs' 应该在里面
            self.assertIn("openzfs", installer_pkg.install_dependencies)
            self.assertIn("avahi-daemon", installer_pkg.install_dependencies)
            
            print(f"解析到的依赖项: {installer_pkg.install_dependencies}")

        finally:
            # 还原全局变量
            paths.SOURCES_DIR = original_sources_dir

if __name__ == '__main__':
    unittest.main()