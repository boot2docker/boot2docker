#!/bin/sh
set -e

. /scripts/functions

#rootmnt=/ramdisk
mountroot() {
	mkdir -p "$rootmnt"
	memSize="$(awk '/^MemTotal:/ { print $2 }' /proc/meminfo)"
	mount -t tmpfs -o size="${memSize}k,mode=0755" tmpfs "$rootmnt"

	tar -xJf /rootfs.tar.xz -C "$rootmnt"
	rm /rootfs.tar.xz

	# initramfs-tools setup scripts need these to exist to mount over them
	mkdir -p "$rootmnt/dev" "$rootmnt/sys" "$rootmnt/proc"

	# initramfs-tools panics the kernel if this is missing
	touch /conf/param.conf
	# TODO file bug on initramfs-tools for this
}
