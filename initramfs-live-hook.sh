#!/bin/sh
set -e

. /usr/share/initramfs-tools/hook-functions

if [ -e /tmp/rootfs.tar.xz ]; then
	cp -a /tmp/rootfs.tar.xz "${DESTDIR}/rootfs.tar.xz"
fi
