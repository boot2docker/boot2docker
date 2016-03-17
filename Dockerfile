FROM debian:jessie

RUN apt-get update && apt-get -y install  unzip \
                        xz-utils \
                        curl \
                        bc \
                        git \
                        build-essential \
                        golang \
                        cpio \
                        gcc libc6 libc6-dev \
                        kmod \
                        squashfs-tools \
                        genisoimage \
                        xorriso \
                        syslinux \
                        isolinux \
                        automake \
                        pkg-config \
                        p7zip-full

# https://www.kernel.org/
ENV KERNEL_VERSION  4.1.19

# Fetch the kernel sources
RUN curl --retry 10 https://www.kernel.org/pub/linux/kernel/v${KERNEL_VERSION%%.*}.x/linux-$KERNEL_VERSION.tar.xz | tar -C / -xJ && \
    mv /linux-$KERNEL_VERSION /linux-kernel

# http://aufs.sourceforge.net/
ENV AUFS_REPO       https://github.com/sfjro/aufs4-standalone
ENV AUFS_BRANCH     aufs4.1.13+
ENV AUFS_COMMIT     9b0fe5a0ac42f9dca6ecf3261178ce101a270948
# we use AUFS_COMMIT to get stronger repeatability guarantees

# Download AUFS and apply patches and files, then remove it
RUN git clone -b "$AUFS_BRANCH" "$AUFS_REPO" /aufs-standalone && \
    cd /aufs-standalone && \
    git checkout -q "$AUFS_COMMIT" && \
    cd /linux-kernel && \
    cp -r /aufs-standalone/Documentation /linux-kernel && \
    cp -r /aufs-standalone/fs /linux-kernel && \
    cp -r /aufs-standalone/include/uapi/linux/aufs_type.h /linux-kernel/include/uapi/linux/ && \
    set -e && for patch in \
        /aufs-standalone/aufs*-kbuild.patch \
        /aufs-standalone/aufs*-base.patch \
        /aufs-standalone/aufs*-mmap.patch \
        /aufs-standalone/aufs*-standalone.patch \
        /aufs-standalone/aufs*-loopback.patch \
    ; do \
        patch -p1 < "$patch"; \
    done

COPY kernel_config /linux-kernel/.config

RUN jobs=$(nproc); \
    cd /linux-kernel && \
    make -j ${jobs} oldconfig && \
    make -j ${jobs} bzImage && \
    make -j ${jobs} modules

# The post kernel build process

ENV ROOTFS          /rootfs
ENV TCL_REPO_BASE   http://tinycorelinux.net/7.x/x86_64
# Note that the ncurses is here explicitly so that top continues to work
ENV TCZ_DEPS        iptables \
                    iproute2 \
                    openssh openssl \
                    tar \
                    gcc_libs \
                    ncurses \
                    acpid \
                    xz liblzma \
                    git expat2 libiconv libidn libgpg-error libgcrypt libssh2 \
                    nfs-utils tcp_wrappers portmap rpcbind libtirpc \
                    rsync attr acl \
                    curl ntpclient \
                    procps glib2 libtirpc libffi fuse pcre \
                    udev-lib udev-extra \
                    liblvm2 \
                    parted

# Make the ROOTFS
RUN mkdir -p $ROOTFS

# Prepare the build directory (/tmp/iso)
RUN mkdir -p /tmp/iso/boot

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
RUN curl -fL http://http.debian.net/debian/pool/main/libc/libcap2/libcap2_2.22.orig.tar.gz | tar -C / -xz && \
    cd /libcap-2.22 && \
    sed -i 's/LIBATTR := yes/LIBATTR := no/' Make.Rules && \
    make && \
    mkdir -p output && \
    make prefix=`pwd`/output install && \
    mkdir -p $ROOTFS/usr/local/lib && \
    cp -av `pwd`/output/lib64/* $ROOTFS/usr/local/lib

# Make sure the kernel headers are installed for aufs-util, and then build it
RUN cd /linux-kernel && \
    make INSTALL_HDR_PATH=/tmp/kheaders headers_install && \
    cd / && \
    git clone https://github.com/Distrotech/aufs-util.git && \
    cd /aufs-util && \
    git checkout 5e0c348bd8b1898beb1e043b026bcb0e0c7b0d54 && \
    CPPFLAGS="-I/tmp/kheaders/include" CLFAGS=$CPPFLAGS LDFLAGS=$CPPFLAGS make && \
    DESTDIR=$ROOTFS make install && \
    rm -rf /tmp/kheaders

# Prepare the ISO directory with the kernel
RUN cp -v /linux-kernel/arch/x86_64/boot/bzImage /tmp/iso/boot/vmlinuz64

# Download the rootfs, don't unpack it though:
RUN curl -fL -o /tcl_rootfs.gz $TCL_REPO_BASE/release/distribution_files/rootfs64.gz

# Install the TCZ dependencies
RUN for dep in $TCZ_DEPS; do \
    echo "Download $TCL_REPO_BASE/tcz/$dep.tcz" &&\
        curl -fL -o /tmp/$dep.tcz $TCL_REPO_BASE/tcz/$dep.tcz && \
        unsquashfs -f -d $ROOTFS /tmp/$dep.tcz && \
        rm -f /tmp/$dep.tcz ;\
    done

# get generate_cert
RUN curl -fL -o $ROOTFS/usr/local/bin/generate_cert https://github.com/SvenDowideit/generate_cert/releases/download/0.2/generate_cert-0.2-linux-amd64 && \
    chmod +x $ROOTFS/usr/local/bin/generate_cert

# Build VBox guest additions
ENV VBOX_VERSION 5.0.16
RUN mkdir -p /vboxguest && \
    cd /vboxguest && \
    \
    curl -fL -o vboxguest.iso http://download.virtualbox.org/virtualbox/${VBOX_VERSION}/VBoxGuestAdditions_${VBOX_VERSION}.iso && \
    7z x vboxguest.iso -ir'!VBoxLinuxAdditions.run' && \
    rm vboxguest.iso && \
    \
    sh VBoxLinuxAdditions.run --noexec --target . && \
    mkdir amd64 && tar -C amd64 -xjf VBoxGuestAdditions-amd64.tar.bz2 && \
    rm VBoxGuestAdditions*.tar.bz2 && \
    \
    KERN_DIR=/linux-kernel/ make -C amd64/src/vboxguest-${VBOX_VERSION} && \
    cp amd64/src/vboxguest-${VBOX_VERSION}/*.ko $ROOTFS/lib/modules/$KERNEL_VERSION-boot2docker/ && \
    \
    mkdir -p $ROOTFS/sbin && \
    cp amd64/lib/VBoxGuestAdditions/mount.vboxsf amd64/sbin/VBoxService $ROOTFS/sbin/ && \
    mkdir -p $ROOTFS/bin && \
    cp amd64/bin/VBoxClient amd64/bin/VBoxControl $ROOTFS/bin/

# Install build dependencies for VMware Tools
RUN apt-get update && apt-get install -y \
        autoconf \
        libdumbnet-dev \
        libdumbnet1 \
        libfuse-dev \
        libfuse2 \
        libglib2.0-0 \
        libglib2.0-dev \
        libmspack-dev \
        libssl-dev \
        libtirpc-dev \
        libtirpc1 \
        libtool \
    && rm -rf /var/lib/apt/lists/*

# Build VMware Tools
ENV OVT_VERSION 10.0.0-3000743

RUN curl --retry 10 -fsSL "https://github.com/vmware/open-vm-tools/archive/open-vm-tools-${OVT_VERSION}.tar.gz" | tar -xz --strip-components=1 -C /

# Compile user space components, we're no longer building kernel module as we're
# now bundling FUSE shared folders support.
RUN cd /open-vm-tools && \
    autoreconf -i && \
    ./configure --disable-multimon --disable-docs --disable-tests --with-gnu-ld \
                --without-kernel-modules --without-procps --without-gtk2 \
                --without-gtkmm --without-pam --without-x --without-icu \
                --without-xerces --without-xmlsecurity --without-ssl && \
    make LIBS="-ltirpc" CFLAGS="-Wno-implicit-function-declaration" && \
    make DESTDIR=$ROOTFS install &&\
    /open-vm-tools/libtool --finish $ROOTFS/usr/local/lib

# Building the Libdnet library for VMware Tools.
ENV LIBDNET libdnet-1.12
RUN curl -fL -o /tmp/${LIBDNET}.zip https://github.com/dugsong/libdnet/archive/${LIBDNET}.zip &&\
    unzip /tmp/${LIBDNET}.zip -d /vmtoolsd &&\
    cd /vmtoolsd/libdnet-${LIBDNET} && ./configure --build=i486-pc-linux-gnu &&\
    make &&\
    make install && make DESTDIR=$ROOTFS install

# Horrible hack again
RUN cd $ROOTFS && cd usr/local/lib && ln -s libdnet.1 libdumbnet.so.1 &&\
    cd $ROOTFS && ln -s lib lib64

# Download and build Parallels Tools
ENV PRL_MAJOR 11
ENV PRL_VERSION 11.1.0
ENV PRL_BUILD 32202

RUN mkdir -p /prl_tools && \
    curl -fL http://download.parallels.com/desktop/v${PRL_MAJOR}/${PRL_VERSION}/ParallelsTools-${PRL_VERSION}-${PRL_BUILD}-boot2docker.tar.gz \
        | tar -xzC /prl_tools --strip-components 1 &&\
    cd /prl_tools &&\
    cp -Rv tools/* $ROOTFS &&\
    \
    KERNEL_DIR=/linux-kernel/ KVER=$KERNEL_VERSION SRC=/linux-kernel/ PRL_FREEZE_SKIP=1 \
    make -C kmods/ -f Makefile.kmods installme &&\
    \
    find kmods/ -name \*.ko -exec cp {} $ROOTFS/lib/modules/$KERNEL_VERSION-boot2docker/ \;

# Build XenServer Tools
ENV XEN_REPO https://github.com/xenserver/xe-guest-utilities
ENV XEN_BRANCH boot2docker
ENV XEN_COMMIT 4a9417fa61a5ca46676b7073fdb9181fe77ba56e

RUN git clone -b "$XEN_BRANCH" "$XEN_REPO" /xentools \
    && cd /xentools \
    && git checkout -q "$XEN_COMMIT" \
    && make \
    && tar xvf build/dist/*.tgz -C $ROOTFS/

# Make sure that all the modules we might have added are recognized (especially VBox guest additions)
RUN depmod -a -b $ROOTFS $KERNEL_VERSION-boot2docker

COPY VERSION $ROOTFS/etc/version
RUN cp -v $ROOTFS/etc/version /tmp/iso/version

# Get the Docker version that matches our boot2docker version
# Note: `docker version` returns non-true when there is no server to ask
RUN curl -fL -o $ROOTFS/usr/local/bin/docker https://get.docker.com/builds/Linux/x86_64/docker-$(cat $ROOTFS/etc/version) && \
    chmod +x $ROOTFS/usr/local/bin/docker && \
    $ROOTFS/usr/local/bin/docker -v

# Install Tiny Core Linux rootfs
RUN cd $ROOTFS && zcat /tcl_rootfs.gz | cpio -f -i -H newc -d --no-absolute-filenames

# Copy our custom rootfs
COPY rootfs/rootfs $ROOTFS

# setup acpi config dir &
# tcl6's sshd is compiled without `/usr/local/sbin` in the path
# Boot2Docker and Docker Machine need `ip`, so I'm linking it in here
RUN cd $ROOTFS \
    && ln -s /usr/local/etc/acpi etc/ \
    && ln -s /usr/local/sbin/ip usr/sbin/

# Build the Hyper-V KVP Daemon
RUN cd /linux-kernel && \
    make INSTALL_HDR_PATH=/tmp/kheaders headers_install && \
    cd /linux-kernel/tools/hv && \
    sed -i 's!\(^CFLAGS = .*\)!\1 -I/tmp/kheaders/include!' Makefile && \
    make hv_kvp_daemon && \
    cp hv_kvp_daemon $ROOTFS/usr/sbin && \
    rm -rf /tmp/kheaders

# These steps can only be run once, so can't be in make_iso.sh (which can be run in chained Dockerfiles)
# see https://github.com/boot2docker/boot2docker/blob/master/doc/BUILD.md

# Make sure init scripts are executable
RUN find $ROOTFS/etc/rc.d/ $ROOTFS/usr/local/etc/init.d/ -exec chmod +x '{}' ';'

# move dhcp.sh out of init.d as we're triggering it manually so its ready a bit faster
RUN mv $ROOTFS/etc/init.d/dhcp.sh $ROOTFS/etc/rc.d/

# Change MOTD
RUN mv $ROOTFS/usr/local/etc/motd $ROOTFS/etc/motd

# Make sure we have the correct bootsync
RUN mv $ROOTFS/boot*.sh $ROOTFS/opt/ && \
	chmod +x $ROOTFS/opt/*.sh

# Make sure we have the correct shutdown
RUN mv $ROOTFS/shutdown.sh $ROOTFS/opt/shutdown.sh && \
	chmod +x $ROOTFS/opt/shutdown.sh

# Add serial console
RUN echo "#!/bin/sh" > $ROOTFS/usr/local/bin/autologin && \
	echo "/bin/login -f docker" >> $ROOTFS/usr/local/bin/autologin && \
	chmod 755 $ROOTFS/usr/local/bin/autologin && \
	echo 'ttyS0:2345:respawn:/sbin/getty -l /usr/local/bin/autologin 9600 ttyS0 vt100' >> $ROOTFS/etc/inittab && \
	echo 'ttyS1:2345:respawn:/sbin/getty -l /usr/local/bin/autologin 9600 ttyS1 vt100' >> $ROOTFS/etc/inittab

# fix "su -"
RUN echo root > $ROOTFS/etc/sysconfig/superuser

# add some timezone files so we're explicit about being UTC
RUN echo 'UTC' > $ROOTFS/etc/timezone \
	&& cp -L /usr/share/zoneinfo/UTC $ROOTFS/etc/localtime

# Get the git versioning info
COPY .git /git/.git
RUN cd /git && \
    GIT_BRANCH=$(git rev-parse --abbrev-ref HEAD) && \
    GITSHA1=$(git rev-parse --short HEAD) && \
    DATE=$(date) && \
    echo "${GIT_BRANCH} : ${GITSHA1} - ${DATE}" > $ROOTFS/etc/boot2docker

# Copy boot params
COPY rootfs/isolinux /tmp/iso/boot/isolinux

COPY rootfs/make_iso.sh /

RUN /make_iso.sh

CMD ["cat", "boot2docker.iso"]
