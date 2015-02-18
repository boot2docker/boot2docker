#!/bin/bash
set -e

# /etc/hostname, /etc/hosts, and /etc/resolv.conf are all bind-mounts in Docker, so we have to set them up here instead of in the Dockerfile or the changes won't stick
grep -q ' /etc/hostname ' /proc/mounts # sanity check
echo 'docker' > /etc/hostname

{
	echo '127.0.0.1   localhost docker'
	echo '::1         localhost ip6-localhost ip6-loopback'
	echo 'fe00::0     ip6-localnet'
	echo 'ff00::0     ip6-mcastprefix'
	echo 'ff02::1     ip6-allnodes'
	echo 'ff02::2     ip6-allrouters'
} > /etc/hosts

{
	echo 'nameserver 8.8.8.8'
	echo 'nameserver 8.8.4.4'
} > /etc/resolv.conf

docker -v > /tmp/iso/version

mkdir -p /tmp/iso/isolinux

cat > /tmp/iso/isolinux/isolinux.cfg <<EOH
serial 0

ui menu.c32
prompt 1
menu title $(head -1 /tmp/iso/version)
timeout 10
EOH

commonAppend='console=ttyS0 console=tty0 boot=live'
extraAppend='cgroup_enable=memory swapaccount=1'

declare -A inits=(
	[sysvinit]='/lib/sysvinit/init'
	[systemd]='/lib/systemd/systemd'
)
for init in '' sysvinit systemd; do
	cat >> /tmp/iso/isolinux/isolinux.cfg <<EOE

label docker${init:+-$init}
	menu label Docker${init:+ ($init)}
	linux /live/vmlinuz
	initrd /live/initrd.img
	append${init:+ init=${inits[$init]}} $commonAppend $extraAppend loglevel=3
EOE
done

cat >> /tmp/iso/isolinux/isolinux.cfg <<EOE

label docker-safe
	menu label Docker (recovery mode)
	linux /live/vmlinuz
	initrd /live/initrd.img
	append $commonAppend single

label docker-bootdebug
	menu label Docker (boot debug)
	linux /live/vmlinuz
	initrd /live/initrd.img
	append $commonAppend $extraAppend systemd.log_level=debug systemd.log_target=console debug=vc
EOE

mkdir -p /tmp/iso/live

echo >&2 'Building the rootfs tarball ...'
tar --exclude-from /tmp/excludes -cJf /tmp/rootfs.tar.xz /

echo >&2 'Updating initrd.img ...'
update-initramfs -k all -u
ln -L /vmlinuz /initrd.img /tmp/iso/live/

# volume IDs must be 32 characters or less
volid="$(head -1 /tmp/iso/version | sed 's/ version / v/')"
if [ ${#volid} -gt 32 ]; then
	volid="$(printf '%-32.32s' "$volid")"
fi

echo >&2 'Building the ISO ...'
xorriso \
	-as mkisofs \
	-A 'Docker' \
	-V "$volid" \
	-l -J -rock -joliet-long \
	-isohybrid-mbr /tmp/isohdpfx.bin \
	-partition_offset 16 \
	-b isolinux/isolinux.bin \
	-c isolinux/boot.cat \
	-no-emul-boot \
	-boot-load-size 4 \
	-boot-info-table \
	-o /tmp/docker.iso \
	/tmp/iso

rm -rf /tmp/iso/live /tmp/rootfs.tar.xz
