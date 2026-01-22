#!/bin/bash
mkdir /tmp/abc
mount -t squashfs /cdrom/TrueNAS-SCALE.update /tmp/abc
cd /tmp/abc