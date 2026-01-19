Create first iso of zuti NAS
```
mkdir /tmp/abc
mount -t squashfs /cdrom/TrueNAS...update /tmp/abc

or /cdrom/load-update.sh

cd /tmp/abc/truenas_install/scipts
## delete all data on /dev/sda
./call.sh -f /dev/sda
cd /tmp/
./zuti-call.sh /dev/sda
passwd root
```