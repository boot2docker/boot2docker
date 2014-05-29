FROM debian:wheezy
MAINTAINER Steeve Morin "steeve.morin@gmail.com"

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
                        p7zip-full

ENV KERNEL_VERSION  3.15.3
ENV AUFS_BRANCH     aufs3.15

# Fetch the kernel sources
RUN curl --retry 10 https://www.kernel.org/pub/linux/kernel/v3.x/linux-$KERNEL_VERSION.tar.xz | tar -C / -xJ && \
    mv /linux-$KERNEL_VERSION /linux-kernel

# Download AUFS and apply patches and files, then remove it
RUN git clone -b $AUFS_BRANCH --depth 1 git://git.code.sf.net/p/aufs/aufs3-standalone && \
    cd aufs3-standalone && \
    cd /linux-kernel && \
    for patch in aufs3-kbuild aufs3-base aufs3-mmap aufs3-standalone; do \
        patch -p1 < /aufs3-standalone/$patch.patch; \
    done && \
    cp -r /aufs3-standalone/Documentation /linux-kernel && \
    cp -r /aufs3-standalone/fs /linux-kernel && \
    cp -r /aufs3-standalone/include/uapi/linux/aufs_type.h /linux-kernel/include/uapi/linux/

COPY kernel_config /linux-kernel/.config

RUN jobs=$(nproc); \
    cd /linux-kernel && \
    make -j ${jobs} oldconfig && \
    make -j ${jobs} bzImage && \
    make -j ${jobs} modules

# The post kernel build process

ENV ROOTFS          /rootfs
ENV VBOX_VERSION    4.3.12
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

# Build VBox guest additions
RUN mkdir -p /vboxguest && \
    cd /vboxguest && \
    curl -L -o vboxguest.iso http://download.virtualbox.org/virtualbox/${VBOX_VERSION}/VBoxGuestAdditions_${VBOX_VERSION}.iso && \
    7z x vboxguest.iso -ir'!VBoxLinuxAdditions.run' && \
    sh VBoxLinuxAdditions.run --noexec --target . && \
    mkdir x86 && cd x86 && tar xvjf ../VBoxGuestAdditions-x86.tar.bz2 && cd .. && \
    mkdir amd64 && cd amd64 && tar xvjf ../VBoxGuestAdditions-amd64.tar.bz2 && cd .. && \
    cd amd64/src/vboxguest-${VBOX_VERSION} && KERN_DIR=/linux-kernel/ make && cd ../../.. && \
    cp amd64/src/vboxguest-${VBOX_VERSION}/*.ko $ROOTFS/lib/modules/$KERNEL_VERSION-tinycore64 && \
    mkdir -p $ROOTFS/sbin && cp x86/lib/VBoxGuestAdditions/mount.vboxsf $ROOTFS/sbin/

# Download the rootfs, don't unpack it though:
RUN curl -L -o /tcl_rootfs.gz $TCL_REPO_BASE/release/distribution_files/rootfs.gz

# Install the TCZ dependencies
RUN for dep in $TCZ_DEPS; do \
    echo "Download $TCL_REPO_BASE/tcz/$dep.tcz" &&\
        curl -L -o /tmp/$dep.tcz $TCL_REPO_BASE/tcz/$dep.tcz && \
        unsquashfs -f -d $ROOTFS /tmp/$dep.tcz && \
        rm -f /tmp/$dep.tcz ;\
    done

# Make sure that all the modules we might have added are recognized
RUN depmod -a -b $ROOTFS $KERNEL_VERSION-tinycore64

COPY VERSION $ROOTFS/etc/version

# Get the Docker version that matches our boot2docker version
# Note: `docker version` returns non-true when there is no server to ask
RUN curl -L -o $ROOTFS/usr/local/bin/docker https://get.docker.io/builds/Linux/x86_64/docker-$(cat $ROOTFS/etc/version) && \
    chmod +x $ROOTFS/usr/local/bin/docker && \
    { $ROOTFS/usr/local/bin/docker version || true; }

# Get the git versioning info
COPY .git /git/.git
RUN cd /git && \
    GIT_BRANCH=$(git rev-parse --abbrev-ref HEAD) && \
    GITSHA1=$(git rev-parse --short HEAD) && \
    DATE=$(date) && \
    echo "${GIT_BRANCH} : ${GITSHA1} - ${DATE}" > $ROOTFS/etc/boot2docker

COPY rootfs/isolinux /isolinux

# Copy our custom rootfs
COPY rootfs/rootfs $ROOTFS

COPY rootfs/make_iso.sh /
RUN /make_iso.sh
CMD ["cat", "boot2docker.iso"]
