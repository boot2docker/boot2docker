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
ENV KERNEL_VERSION  4.4.73

# Fetch the kernel sources
RUN curl --retry 10 https://www.kernel.org/pub/linux/kernel/v${KERNEL_VERSION%%.*}.x/linux-$KERNEL_VERSION.tar.xz | tar -C / -xJ && \
    mv /linux-$KERNEL_VERSION /linux-kernel

# http://aufs.sourceforge.net/
ENV AUFS_REPO       https://github.com/sfjro/aufs4-standalone
ENV AUFS_BRANCH     aufs4.4
ENV AUFS_COMMIT     dcfa30307f2a165069545a0ad2094ca31fcb490b
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

ENV ROOTFS /rootfs

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

# Install mdadm, allow RAID devices to be auto-mounted and probed for persistance.
RUN curl -fL https://www.kernel.org/pub/linux/utils/raid/mdadm/mdadm-4.0.tar.xz | tar -C / -xJ && \
    cd /mdadm-4.0 && \
    sed -i 's;IMPORT{builtin}="blkid";IMPORT{program}="/sbin/blkid -o udev -p $devnode";g' udev-md-raid-arrays.rules && \
    sed -i 's; install-man;;g' Makefile && \
    make && \
    make install DESTDIR=$ROOTFS

# Make sure the kernel headers are installed for aufs-util, and then build it
ENV AUFS_UTIL_REPO    git://git.code.sf.net/p/aufs/aufs-util
ENV AUFS_UTIL_BRANCH  aufs4.1
ENV AUFS_UTIL_COMMIT  bb75870054af06f3e76353de06a4894e9ccb0c5a
RUN set -ex \
	&& git clone -b "$AUFS_UTIL_BRANCH" "$AUFS_UTIL_REPO" /aufs-util \
	&& git -C /aufs-util checkout --quiet "$AUFS_UTIL_COMMIT" \
	&& make -C /linux-kernel headers_install INSTALL_HDR_PATH=/tmp/kheaders \
	&& export CFLAGS='-I/tmp/kheaders/include' \
	&& export CPPFLAGS="$CFLAGS" LDFLAGS="$CFLAGS" \
	&& make -C /aufs-util \
	&& make -C /aufs-util install DESTDIR="$ROOTFS" \
	&& rm -r /tmp/kheaders

# Prepare the ISO directory with the kernel
RUN cp -v /linux-kernel/arch/x86_64/boot/bzImage /tmp/iso/boot/vmlinuz64

ENV TCL_REPO_BASE   http://distro.ibiblio.org/tinycorelinux/7.x/x86_64
# Note that the ncurses is here explicitly so that top continues to work
ENV TCZ_DEPS        iptables \
                    iproute2 \
                    openssh openssl \
                    tar \
                    gcc_libs \
                    ncurses \
                    acpid \
                    xz liblzma \
                    git expat2 libgpg-error libgcrypt libssh2 \
                    nfs-utils tcp_wrappers portmap rpcbind libtirpc \
                    rsync attr acl \
                    curl ntpclient \
                    procps glib2 libtirpc libffi fuse pcre \
                    udev-lib udev-extra \
                    liblvm2 \
                    parted

# Download the rootfs, don't unpack it though:
RUN curl -fL -o /tcl_rootfs.gz $TCL_REPO_BASE/release/distribution_files/rootfs64.gz

# Install the TCZ dependencies
RUN set -ex; \
	for dep in $TCZ_DEPS; do \
		echo "Download $TCL_REPO_BASE/tcz/$dep.tcz"; \
		curl -fSL -o "/tmp/$dep.tcz" "$TCL_REPO_BASE/tcz/$dep.tcz"; \
		unsquashfs -f -d "$ROOTFS" "/tmp/$dep.tcz"; \
		rm -f "/tmp/$dep.tcz"; \
	done

# Install Tiny Core Linux rootfs
RUN cd "$ROOTFS" && zcat /tcl_rootfs.gz | cpio -f -i -H newc -d --no-absolute-filenames

# Extract ca-certificates
RUN set -x \
#  TCL changed something such that these need to be extracted post-install
	&& chroot "$ROOTFS" sh -xc 'ldconfig && /usr/local/tce.installed/openssl' \
#  Docker looks for them in /etc/ssl
	&& ln -sT ../usr/local/etc/ssl "$ROOTFS/etc/ssl" \
#  a little testing is always prudent
	&& cp "$ROOTFS/etc/resolv.conf" resolv.conf.bak \
	&& cp /etc/resolv.conf "$ROOTFS/etc/resolv.conf" \
	&& chroot "$ROOTFS" curl -fsSL 'https://www.google.com' -o /dev/null \
	&& mv resolv.conf.bak "$ROOTFS/etc/resolv.conf"

# Apply horrible hacks
RUN ln -sT lib "$ROOTFS/lib64"

# get generate_cert
RUN curl -fL -o $ROOTFS/usr/local/bin/generate_cert https://github.com/SvenDowideit/generate_cert/releases/download/0.2/generate_cert-0.2-linux-amd64 && \
    chmod +x $ROOTFS/usr/local/bin/generate_cert

# Build VBox guest additions
#   http://download.virtualbox.org/virtualbox/
ENV VBOX_VERSION 5.1.22
#   https://www.virtualbox.org/download/hashes/$VBOX_VERSION/SHA256SUMS
ENV VBOX_SHA256 54df14f234b6aa484b94939ab0f435b5dd859417612b65a399ecc34a62060380
#   (VBoxGuestAdditions_X.Y.Z.iso SHA256, for verification)
RUN set -x && \
    \
    mkdir -p /vboxguest && \
    cd /vboxguest && \
    \
    curl -fL -o vboxguest.iso http://download.virtualbox.org/virtualbox/${VBOX_VERSION}/VBoxGuestAdditions_${VBOX_VERSION}.iso && \
    echo "${VBOX_SHA256} *vboxguest.iso" | sha256sum -c - && \
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

# TODO figure out how to make this work reasonably (these tools try to read /proc/self/exe at startup, even for a simple "--version" check)
## verify that all the above actually worked (at least producing a valid binary, so we don't repeat issue #1157)
#RUN set -x && \
#    chroot "$ROOTFS" VBoxControl --version && \
#    chroot "$ROOTFS" VBoxService --version

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
RUN curl -fL -o /tmp/${LIBDNET}.zip https://github.com/dugsong/libdnet/archive/${LIBDNET}.zip && \
    unzip /tmp/${LIBDNET}.zip -d /vmtoolsd && \
    cd /vmtoolsd/libdnet-${LIBDNET} && ./configure --build=i486-pc-linux-gnu && \
    make && \
    make install && make DESTDIR=$ROOTFS install

# Horrible hack again
RUN ln -sT libdnet.1 "$ROOTFS/usr/local/lib/libdumbnet.so.1" \
	&& readlink -f "$ROOTFS/usr/local/lib/libdumbnet.so.1"

# TCL 7 doesn't ship with libtirpc.so.1 Dummy it up so the VMware tools work again, taken from:
# https://github.com/boot2docker/boot2docker/issues/1157#issuecomment-211647607
RUN ln -sT libtirpc.so "$ROOTFS/usr/local/lib/libtirpc.so.1" \
	&& readlink -f "$ROOTFS/usr/local/lib/libtirpc.so.1"

# verify that all the above actually worked (at least producing a valid binary, so we don't repeat issue #1157)
RUN LD_LIBRARY_PATH='/lib:/usr/local/lib' \
		chroot "$ROOTFS" vmhgfs-fuse --version

# Download and build Parallels Tools
ENV PRL_MAJOR 12
ENV PRL_VERSION 12.1.3-41532

RUN set -ex \
	&& mkdir -p /prl_tools \
	&& curl -fSL "http://download.parallels.com/desktop/v${PRL_MAJOR}/${PRL_VERSION}/ParallelsTools-${PRL_VERSION}-boot2docker.tar.gz" \
		| tar -xzC /prl_tools --strip-components 1 \
	&& cd /prl_tools \
	&& cp -Rv tools/* $ROOTFS \
	\
	&& KERNEL_DIR=/linux-kernel/ KVER="$KERNEL_VERSION" SRC=/linux-kernel/ PRL_FREEZE_SKIP=1 \
		make -C kmods/ -f Makefile.kmods installme \
	\
	&& find kmods/ -name '*.ko' -exec cp {} "$ROOTFS/lib/modules/$KERNEL_VERSION-boot2docker/" ';'

# verify that all the above actually worked (at least producing a valid binary, so we don't repeat issue #1157)
RUN chroot "$ROOTFS" prltoolsd -V

# Build XenServer Tools
ENV XEN_REPO https://github.com/xenserver/xe-guest-utilities
ENV XEN_VERSION v6.6.80

RUN set -ex \
	&& git clone -b "$XEN_VERSION" "$XEN_REPO" /xentools \
	&& make -C /xentools \
	&& tar xvf /xentools/build/dist/*.tgz -C "$ROOTFS"

# TODO find a binary we can attempt running that will verify at least on the surface level that the xentools are working

# Build the Hyper-V KVP Daemon
RUN set -ex \
	&& make -C /linux-kernel headers_install \
	&& cd /linux-kernel/tools/hv \
	&& sed -i 's!\(^CFLAGS = .*\)!\1 -I/tmp/kheaders/include!' Makefile \
	&& make hv_kvp_daemon \
	&& cp hv_kvp_daemon $ROOTFS/usr/sbin \
	&& rm -rf /tmp/kheaders

# Make sure that all the modules we might have added are recognized (especially VBox guest additions)
RUN depmod -a -b "$ROOTFS" "$KERNEL_VERSION-boot2docker"

COPY VERSION $ROOTFS/etc/version
RUN cp -v "$ROOTFS/etc/version" /tmp/iso/version

ENV DOCKER_CHANNEL edge

# Get the Docker binaries with version that matches our boot2docker version.
RUN set -ex; \
	version="$(cat "$ROOTFS/etc/version")"; \
	if [ "${version%-rc*}" != "$version" ]; then \
# all the -rc* releases go in the "test" channel
		DOCKER_CHANNEL='test'; \
	fi; \
	curl -fSL -o /tmp/dockerbin.tgz "https://download.docker.com/linux/static/$DOCKER_CHANNEL/x86_64/docker-$version.tgz"; \
	tar -zxvf /tmp/dockerbin.tgz -C "$ROOTFS/usr/local/bin" --strip-components=1; \
	rm /tmp/dockerbin.tgz; \
	chroot "$ROOTFS" docker -v

# Copy our custom rootfs
COPY rootfs/rootfs $ROOTFS

# setup acpi config dir &
# tcl6's sshd is compiled without `/usr/local/sbin` in the path
# Boot2Docker and Docker Machine need `ip`, so link it elsewhere
RUN ln -svT /usr/local/etc/acpi "$ROOTFS/etc/acpi" \
	&& ln -svT /usr/local/sbin/ip "$ROOTFS/usr/sbin/ip"

# These steps should only be run once, so can't be in make_iso.sh (which can be run in chained Dockerfiles)
# see https://github.com/boot2docker/boot2docker/blob/master/doc/BUILD.md

# Make sure init scripts are executable
RUN find "$ROOTFS/etc/rc.d/" "$ROOTFS/usr/local/etc/init.d/" -type f -exec chmod --changes +x '{}' +

# move dhcp.sh out of init.d as we're triggering it manually so its ready a bit faster
RUN mv -v "$ROOTFS/etc/init.d/dhcp.sh" "$ROOTFS/etc/rc.d/"

# Add serial console
RUN set -ex; \
	for s in 0 1 2 3; do \
		echo "ttyS${s}:2345:respawn:/usr/local/bin/forgiving-getty ttyS${s}" >> "$ROOTFS/etc/inittab"; \
	done; \
	cat "$ROOTFS/etc/inittab"

# fix "su -"
RUN echo root > "$ROOTFS/etc/sysconfig/superuser"

# add some timezone files so we're explicit about being UTC
RUN echo 'UTC' > "$ROOTFS/etc/timezone" \
	&& cp -vL /usr/share/zoneinfo/UTC "$ROOTFS/etc/localtime"

# make sure the "docker" group exists already
RUN chroot "$ROOTFS" addgroup -S docker

# set up subuid/subgid so that "--userns-remap=default" works out-of-the-box
# (see also rootfs/rootfs/etc/sub{uid,gid})
RUN set -x \
	&& chroot "$ROOTFS" addgroup -S dockremap \
	&& chroot "$ROOTFS" adduser -S -G dockremap dockremap

# Get the git versioning info
COPY .git /git/.git
RUN set -ex \
	&& GIT_BRANCH="$(git -C /git rev-parse --abbrev-ref HEAD)" \
	&& GITSHA1="$(git -C /git rev-parse --short HEAD)" \
	&& DATE="$(date)" \
	&& echo "${GIT_BRANCH} : ${GITSHA1} - ${DATE}" \
		| tee "$ROOTFS/etc/boot2docker"

# Copy boot params
COPY rootfs/isolinux /tmp/iso/boot/isolinux

COPY rootfs/make_iso.sh /tmp/make_iso.sh

RUN /tmp/make_iso.sh

CMD ["sh", "-c", "[ -t 1 ] && exec bash || exec cat boot2docker.iso"]
