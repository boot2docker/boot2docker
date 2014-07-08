FROM debian:jessie
MAINTAINER Steeve Morin "steeve.morin@gmail.com"

ENV KERNEL_VERSION  3.15.3
ENV AUFS_BRANCH     aufs3.15
ENV VBOX_VERSION    4.3.12

RUN apt-get update && apt-get -y install  unzip \
                        xz-utils \
                        curl \
                        bc \
                        git \
                        build-essential \
                        cpio \
                        gcc-multilib libc6-i386 libc6-dev-i386 \
                        kmod \
                        squashfs-tools \
                        genisoimage \
                        xorriso \
                        syslinux \
                        automake \
                        pkg-config \
			procps

# Fetch the kernel sources
RUN curl --retry 10 https://www.kernel.org/pub/linux/kernel/v3.x/linux-$KERNEL_VERSION.tar.xz | tar -C / -xJ && \
    mv /linux-$KERNEL_VERSION /linux-kernel

# Download AUFS and apply patches and files, then remove it
RUN git clone git://git.code.sf.net/p/aufs/aufs3-standalone && \
    cd aufs3-standalone && \
    git checkout $AUFS_BRANCH && \
    cd /linux-kernel && \
    for patch in aufs3-kbuild aufs3-base aufs3-mmap aufs3-standalone; do \
        patch -p1 < /aufs3-standalone/$patch.patch; \
    done && \
    cp -r /aufs3-standalone/Documentation /linux-kernel && \
    cp -r /aufs3-standalone/fs /linux-kernel && \
    cp -r /aufs3-standalone/include/uapi/linux/aufs_type.h /linux-kernel/include/uapi/linux/

RUN mkdir /vbox
RUN curl -Lo /vbox/VBoxGuestAdditions_$VBOX_VERSION.iso http://download.virtualbox.org/virtualbox/$VBOX_VERSION/VBoxGuestAdditions_$VBOX_VERSION.iso
RUN xorriso -osirrox on -dev /vbox/VBoxGuestAdditions_$VBOX_VERSION.iso -extract / /vbox
RUN test -x /vbox/autorun.sh
ADD kernel_config /linux-kernel/.config

RUN jobs=$(nproc); \
    cd /linux-kernel && \
    make -j ${jobs} oldconfig && \
    make -j ${jobs} bzImage && \
    make -j ${jobs} modules

# The post kernel build process

ENV ROOTFS          /rootfs
ENV TCL_REPO_BASE   http://tinycorelinux.net/5.x/x86
ENV TCZ_DEPS        iptables \
                    iproute2 \
                    openssh openssl-1.0.0 \
                    tar \
                    gcc_libs \
                    acpid \
                    xz liblzma \
                    git expat2 libiconv libidn libgpg-error libgcrypt libssh2 \
                    nfs-utils tcp_wrappers portmap rpcbind libtirpc \
                    curl ntpclient

# Make the ROOTFS
RUN mkdir -p $ROOTFS

# Install the kernel modules in $ROOTFS
RUN cd /linux-kernel && \
    make INSTALL_MOD_PATH=$ROOTFS modules_install firmware_install

# Remove useless kernel modules, based on unclejack/debian2docker
RUN cd $ROOTFS/lib/modules && \
    rm -rf ./*/kernel/sound/* && \
    rm -rf ./*/kernel/drivers/gpu/* && \
    rm -rf ./*/kernel/drivers/infiniband/* && \
    rm -rf ./*/kernel/drivers/isdn/* && \
    rm -rf ./*/kernel/drivers/media/* && \
    rm -rf ./*/kernel/drivers/staging/lustre/* && \
    rm -rf ./*/kernel/drivers/staging/comedi/* && \
    rm -rf ./*/kernel/fs/ocfs2/* && \
    rm -rf ./*/kernel/net/bluetooth/* && \
    rm -rf ./*/kernel/net/mac80211/* && \
    rm -rf ./*/kernel/net/wireless/*

RUN /vbox/VBoxLinuxAdditions.run --noexec --nox11 --keep --target /tmp/
# Annoyingly installs from x86_64 but creates our /var/lib/VBoxGuestAdditions files
RUN cd /tmp && ./install.sh /tmp/VBoxGuestAdditions-x86.tar.bz2 --force --no-setup || true # still returns 1
# Overwrite with correct binaries.
RUN tar -C /opt/VBoxGuestAdditions-$VBOX_VERSION -jxf /tmp/VBoxGuestAdditions-x86.tar.bz2

RUN mkdir -p $ROOTFS/usr/bin
RUN for i in /opt/VBoxGuestAdditions-$VBOX_VERSION/bin/*; do \
      test -e "$i" && cp "/$i" "$ROOTFS/usr/bin/$(basename $i)"; \
    done

RUN mkdir -p $ROOTFS/sbin
RUN mkdir -p $ROOTFS/usr/sbin
RUN install -m 0755 -o root -g root -t $ROOTFS/sbin /opt/VBoxGuestAdditions-4.3.12/lib/VBoxGuestAdditions/mount.vboxsf
RUN cd /opt/VBoxGuestAdditions-4.3.12/sbin; install -m 0755 -o root -g root -t $ROOTFS/usr/sbin /opt/VBoxGuestAdditions-4.3.12/sbin/VBoxService

RUN mkdir -p $ROOTFS/usr/local/etc/init.d
RUN cd opt/VBoxGuestAdditions-4.3.12/init; install -m 0755 -o root -g root -t $ROOTFS/usr/local/etc/init.d vboxadd vboxadd-service

RUN mkdir -p $ROOTFS/var/lib/VBoxGuestAdditions
RUN cd /var/lib/VBoxGuestAdditions; install -m 0644 -o root -g root -t $ROOTFS/var/lib/VBoxGuestAdditions config filelist

# Manually build the kernel modules
RUN mkdir -p $ROOTFS/lib/modules/${KERNEL_VERSION}-tinycore64
RUN cd /opt/VBoxGuestAdditions-$VBOX_VERSION/src/vboxguest-$VBOX_VERSION; for i in vboxguest vboxsf; do \
      test -d $i && \
      make -C $i KERN_DIR=/linux-kernel MODULE_DIR=$ROOTFS/lib/modules/${KERNEL_VERSION}-tinycore64/misc install; \
    done || true

# Make sure the dependencies get updated
RUN depmod -b $ROOTFS ${KERNEL_VERSION}-tinycore64

# Cleanup
RUN rm -rf /tmp/*

# Install libcap
RUN curl -L ftp://ftp.de.debian.org/debian/pool/main/libc/libcap2/libcap2_2.22.orig.tar.gz | tar -C / -xz && \
    cd /libcap-2.22 && \
    sed -i 's/LIBATTR := yes/LIBATTR := no/' Make.Rules && \
    sed -i 's/\(^CFLAGS := .*\)/\1 -m32/' Make.Rules && \
    make && \
    mkdir -p output && \
    make prefix=`pwd`/output install && \
    mkdir -p $ROOTFS/usr/local/lib && \
    cp -av `pwd`/output/lib64/* $ROOTFS/usr/local/lib

# Make sure the kernel headers are installed for aufs-util, and then build it
RUN cd /linux-kernel && \
    make INSTALL_HDR_PATH=/tmp/kheaders headers_install && \
    cd / && \
    git clone git://git.code.sf.net/p/aufs/aufs-util && \
    cd /aufs-util && \
    git checkout aufs3.9 && \
    CPPFLAGS="-m32 -I/tmp/kheaders/include" CLFAGS=$CPPFLAGS LDFLAGS=$CPPFLAGS make && \
    DESTDIR=$ROOTFS make install && \
    rm -rf /tmp/kheaders

# Download the rootfs, don't unpack it though:
RUN curl -L -o /tcl_rootfs.gz $TCL_REPO_BASE/release/distribution_files/rootfs.gz

# Install the TCZ dependencies
RUN for dep in $TCZ_DEPS; do \
	echo "Download $TCL_REPO_BASE/tcz/$dep.tcz" &&\
        curl -L -o /tmp/$dep.tcz $TCL_REPO_BASE/tcz/$dep.tcz && \
        unsquashfs -f -d $ROOTFS /tmp/$dep.tcz && \
        rm -f /tmp/$dep.tcz ;\
    done

ADD rootfs/isolinux /isolinux
ADD rootfs/make_iso.sh /

# Copy over out custom rootfs
ADD rootfs/rootfs $ROOTFS

# Make sure init scripts are executable
RUN find $ROOTFS/etc/rc.d/ -exec chmod +x {} \; && \
    find $ROOTFS/usr/local/etc/init.d/ -exec chmod +x {} \;

#get the latest docker
RUN curl -L -o $ROOTFS/usr/local/bin/docker https://get.docker.io/builds/Linux/x86_64/docker-latest && \
    chmod +x $ROOTFS/usr/local/bin/docker && \
    $ROOTFS/usr/local/bin/docker version || true

# get the git versioning info
ADD . /gitrepo
RUN cd /gitrepo && \
    GIT_BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null) && \
    GITSHA1=$(git rev-parse --short HEAD) && \
    DATE=$(date) && \
    echo "${GIT_BRANCH} : ${GITSHA1} - ${DATE}" > $ROOTFS/etc/boot2docker

# Download Tiny Core Linux rootfs
RUN cd $ROOTFS && zcat /tcl_rootfs.gz | cpio -f -i -H newc -d --no-absolute-filenames

# Change MOTD
RUN mv $ROOTFS/usr/local/etc/motd $ROOTFS/etc/motd

# Make sure we have the correct bootsync
RUN mv $ROOTFS/bootsync.sh $ROOTFS/opt/bootsync.sh
RUN chmod +x $ROOTFS/opt/bootsync.sh

# Make sure we have the correct shutdown
RUN mv $ROOTFS/shutdown.sh $ROOTFS/opt/shutdown.sh
RUN chmod +x $ROOTFS/opt/shutdown.sh

#add serial console
RUN echo "ttyS0:2345:respawn:/sbin/getty -l /usr/local/bin/autologin 9600 ttyS0 vt100" >> $ROOTFS/etc/inittab
RUN echo "#!/bin/sh" > $ROOTFS/usr/local/bin/autologin && \
    echo "/bin/login -f docker" >> $ROOTFS/usr/local/bin/autologin && \
    chmod 755 $ROOTFS/usr/local/bin/autologin

RUN /make_iso.sh
CMD ["cat", "boot2docker.iso"]
