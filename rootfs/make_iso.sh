#!/bin/sh

# Download Tiny Core Linux rootfs
cd $ROOTFS
zcat /tcl_rootfs.gz | cpio -f -i -H newc -d --no-absolute-filenames  > /dev/null 2>&1
cd -  > /dev/null 2>&1



# Post download rootfs overwrites
# Append the fstab entries for LXC
cat $ROOTFS/usr/local/etc/fstab >> $ROOTFS/etc/fstab
rm -f $ROOTFS/usr/local/etc/fstab

# Change MOTD
mv $ROOTFS/usr/local/etc/motd $ROOTFS/etc/motd

# Download the latest Docker
curl -s -L -o $ROOTFS/usr/local/bin/docker https://get.docker.io/builds/Linux/x86_64/docker-latest
chmod +x $ROOTFS/usr/local/bin/docker

# Make sure we have the correct bootsync
mv $ROOTFS/bootsync.sh $ROOTFS/opt/bootsync.sh
chmod +x $ROOTFS/opt/bootsync.sh

# Prepare the ISO directory with the kernel
mkdir -p /tmp/iso/boot
cp /linux-3.12.1/arch/x86_64/boot/bzImage /tmp/iso/boot/vmlinuz64
cp -r /isolinux /tmp/iso/boot

# Pack the rootfs
cd $ROOTFS
find | cpio -o -H newc | xz -9 --format=lzma > /tmp/iso/boot/initrd.img
cd -

# Make the ISO
# Note: only "-isohybrid-mbr /..." is specific to xorriso.
# It builds an image that can be used as an ISO *and* a disk image.
xorriso -as mkisofs \
    -l -J -R -V boot2docker -no-emul-boot -boot-load-size 4 -boot-info-table \
    -b boot/isolinux/isolinux.bin -c boot/isolinux/boot.cat \
    -isohybrid-mbr /usr/lib/syslinux/isohdpfx.bin \
    -o /boot2docker.iso /tmp/iso
