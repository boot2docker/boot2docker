#!/bin/sh
set -e

# Make sure init scripts are executable
find $ROOTFS/etc/rc.d/ $ROOTFS/usr/local/etc/init.d/ -exec chmod +x '{}' ';'

# Download Tiny Core Linux rootfs
( cd $ROOTFS && zcat /tcl_rootfs.gz | cpio -f -i -H newc -d --no-absolute-filenames )

# Change MOTD
mv $ROOTFS/usr/local/etc/motd $ROOTFS/etc/motd

# Make sure we have the correct bootsync
mv $ROOTFS/boot*.sh $ROOTFS/opt/
chmod +x $ROOTFS/opt/*.sh



# Make sure we have the correct shutdown
mv $ROOTFS/shutdown.sh $ROOTFS/opt/shutdown.sh
chmod +x $ROOTFS/opt/shutdown.sh

# Add serial console
cat > $ROOTFS/usr/local/bin/autologin <<'EOF'
#!/bin/sh
/bin/login -f docker
EOF
chmod 755 $ROOTFS/usr/local/bin/autologin
echo 'ttyS0:2345:respawn:/sbin/getty -l /usr/local/bin/autologin 9600 ttyS0 vt100' >> $ROOTFS/etc/inittab

# Ensure init system invokes /opt/shutdown.sh on reboot or shutdown.
#  1) Find three lines with `useBusyBox`, blank, and `clear`
#  2) insert run op after those three lines
sed -i "1,/^useBusybox/ { /^useBusybox/ { N;N; /^useBusybox\n\nclear/ a\
\\\n\
# Run boot2docker shutdown script\n\
test -x \"/opt/shutdown.sh\" && /opt/shutdown.sh\n
} }" $ROOTFS/etc/init.d/rc.shutdown
# Verify sed worked
grep -q "/opt/shutdown.sh" $ROOTFS/etc/init.d/rc.shutdown || ( echo "Error: failed to insert shutdown script into /etc/init.d/rc.shutdown"; exit 1 )

# Make some handy symlinks (so these things are easier to find)
ln -fs /var/lib/boot2docker/docker.log $ROOTFS/var/log/
ln -fs /usr/local/etc/init.d/docker $ROOTFS/etc/init.d/

# Setup /etc/os-release with some nice contents
b2dVersion="$(cat $ROOTFS/etc/version)" # something like "1.1.0"
b2dDetail="$(cat $ROOTFS/etc/boot2docker)" # something like "master : 740106c - Tue Jul 29 03:29:25 UTC 2014"
tclVersion="$(cat $ROOTFS/usr/share/doc/tc/release.txt)" # something like "5.3"
cat > $ROOTFS/etc/os-release <<-EOOS
NAME=Boot2Docker
VERSION=$b2dVersion
ID=boot2docker
ID_LIKE=tcl
VERSION_ID=$b2dVersion
PRETTY_NAME="Boot2Docker $b2dVersion (TCL $tclVersion); $b2dDetail"
ANSI_COLOR="1;34"
HOME_URL="http://boot2docker.io"
SUPPORT_URL="https://github.com/boot2docker/boot2docker"
BUG_REPORT_URL="https://github.com/boot2docker/boot2docker/issues"
EOOS

# from the bootlog PR
rm -rf $ROOTFS/var/log/docker.log
rm -rf $ROOTFS/etc/init.d/docker
ln -s /var/lib/boot2docker/docker.log $ROOTFS/var/log/
ln -s /usr/local/etc/init.d/docker $ROOTFS/etc/init.d/
#chmod +x  /usr/local/etc/init.d/docker
chmod +x /gitrepo/rootfs/rootfs/usr/local/etc/init.d/docker

# Prepare the ISO directory with the kernel
mkdir -p /tmp/iso/boot
cp -v /linux-kernel/arch/x86_64/boot/bzImage /tmp/iso/boot/vmlinuz64
cp -vr /isolinux /tmp/iso/boot

# Pack the rootfs
cd $ROOTFS
find | ( set -x; cpio -o -H newc | xz -9 --format=lzma --verbose --verbose ) > /tmp/iso/boot/initrd.img
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
