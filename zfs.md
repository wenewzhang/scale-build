```
apt update
apt upgrade
cd zfs
ls
./configure
apt install zlib1g-dev
./configure
apt install libuuid-devel
apt install uuid-dev
./configure
git log
git
apt install git
git status
git log
git tag
apt install -y build-essential autoconf automake libtool gawk libblkid-dev uuid-dev libudev-dev libssl-dev zlib1g-dev libaio-dev libattr1-dev libelf-dev python3-dev libffi-dev
./configure
apt install libtirpc-dev
./configure
make
ls
ls -la
./zfs
./zfs version
modprobe zfs
modprobe zfs
modprobe zfs
ls
find /lib/modules/$(uname -r) -name "zfs.ko*"
find /lib/modules/$(uname -r) -name "zfs.ko*"
ls
pwd
ls
dpkg-buildpackage -us -uc -b
sudo apt install -y abigail-tools debhelper-compat=13 dh-python dh-sequence-dkms libcurl4-openssl-dev libpam0g-dev lsb-release po-debconf python3-all-dev python3-cffi python3-setuptools python3-sphinx
dpkg-buildpackage -us -uc -b
# 1. 安装 locales 包（如果未安装）
sudo apt update && sudo apt install -y locales
# 2. 生成 en_US.UTF-8
echo "en_US.UTF-8 UTF-8" | sudo tee -a /etc/locale.gen
sudo locale-gen en_US.UTF-8
# 3. 设置环境变量
export LANG=en_US.UTF-8
export LC_ALL=en_US.UTF-8
dpkg-buildpackage -us -uc -b

```