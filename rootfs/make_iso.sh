#!/bin/sh
set -e

# Download Tiny Core Linux rootfs
cd $ROOTFS
zcat /tcl_rootfs.gz | cpio -f -i -H newc -d --no-absolute-filenames
cd -

# from 3.14 we seem to be missing the modules.dep files - rebuild
# TODO: look into why depmod isn't in /sbin/ anymore
$ROOTFS/sbin/depmod -b $ROOTFS ${KERNEL_VERSION}-tinycore64

# Post download rootfs overwrites
# Append the fstab entries for LXC
cat $ROOTFS/usr/local/etc/fstab >> $ROOTFS/etc/fstab
rm -f $ROOTFS/usr/local/etc/fstab

# Change MOTD
mv $ROOTFS/usr/local/etc/motd $ROOTFS/etc/motd

# Make sure we have the correct bootsync
mv $ROOTFS/bootsync.sh $ROOTFS/opt/bootsync.sh
chmod +x $ROOTFS/opt/bootsync.sh

# Make sure we have the correct shutdown
mv $ROOTFS/shutdown.sh $ROOTFS/opt/shutdown.sh
chmod +x $ROOTFS/opt/shutdown.sh

# Ensure init system invokes /opt/shutdown.sh on reboot or shutdown.
#  1) Find three lines with `useBusyBox`, blank, and `clear`
#  2) insert run op after those three lines
sed -i "1,/^useBusybox/ { /^useBusybox/ { N;N; /^useBusybox\n\nclear/ a\
\\\n\
# Run boot2docker shutdown script\n\
test -x \"/opt/shutdown.sh\" && /opt/shutdown.sh\n
} }" $ROOTFS/etc/init.d/rc.shutdown
# Verify sed worked
grep "/opt/shutdown.sh" $ROOTFS/etc/init.d/rc.shutdown || ( echo "Error: failed to insert shutdown script into /etc/init.d/rc.shutdown"; exit 1 )

# Make some handy symlinks (so these things are easier to find)
ln -s /var/lib/boot2docker/docker.log $ROOTFS/var/log/
ln -s /usr/local/etc/init.d/docker $ROOTFS/etc/init.d/

# Prepare the ISO directory with the kernel
mkdir -p /tmp/iso/boot
cp -v /linux-kernel/arch/x86_64/boot/bzImage /tmp/iso/boot/vmlinuz64
cp -vr /isolinux /tmp/iso/boot

# Pack the rootfs
cd $ROOTFS
find | cpio -o -H newc | xz -9 --format=lzma > /tmp/iso/boot/initrd.img
cd -

cp -v $ROOTFS/etc/version /tmp/iso/version

# Make the ISO
# Note: only "-isohybrid-mbr /..." is specific to xorriso.
# It builds an image that can be used as an ISO *and* a disk image.
xorriso -as mkisofs \
    -l -J -R -V boot2docker -no-emul-boot -boot-load-size 4 -boot-info-table \
    -b boot/isolinux/isolinux.bin -c boot/isolinux/boot.cat \
    -isohybrid-mbr /usr/lib/syslinux/isohdpfx.bin \
    -o /boot2docker.iso /tmp/iso
