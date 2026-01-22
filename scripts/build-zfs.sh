#!/bin/bash
if [ $# -ne 2 ]; then
    echo "Usage: $0 <path>"
    echo "Example: $0 /.data/zfs/ ./tmp/cache/baseroot-rootfs.squashfs"
    exit 1
fi
mkdir -p $1
cp $2 $1
pushd $1
unsquashfs basechroot-rootfs.squashfs

tee ./squashfs-root/etc/apt/sources.list.d/debian.sources <<EOF
Types: deb deb-src
URIs: http://deb.debian.org/debian/
Suites: trixie trixie-updates
Components: main contrib non-free non-free-firmware
Signed-By: /usr/share/keyrings/debian-archive-keyring.gpg

Types: deb deb-src
URIs: http://security.debian.org/debian-security
Suites: trixie-security
Components: main contrib non-free non-free-firmware
Signed-By: /usr/share/keyrings/debian-archive-keyring.gpg
EOF

tee ./squashfs-root/fetch-packages.sh <<EOF
#!/bin/bash
apt update 
apt upgrade -y
apt install -y zlib1g-dev
apt install -y libuuid-devel
apt install -y uuid-dev
apt install -y git
apt install -y build-essential autoconf automake libtool gawk libblkid-dev uuid-dev libudev-dev libssl-dev zlib1g-dev libaio-dev libattr1-dev libelf-dev python3-dev libffi-dev
apt install -y libtirpc-dev
mkdir -p zfs
pushd zfs
git clone https://github.com/johnramsden/zectl.git
git clone https://salsa.debian.org/zfsonlinux-team/zfs.git
pushd zfs
apt install -y linux-headers-amd64
./configure
make
dpkg-buildpackage -us -uc -b
EOF

chmod +x ./squashfs-root/fetch-packages.sh


chroot ${1}squashfs-root/
