FROM debian:jessie

#Change libc6-i386 by libc6. Future test might involve libc6-amd64
RUN apt-get update && apt-get -y install  unzip \
                        xz-utils \
                        curl \
                        bc \
                        git \
                        build-essential \
                        cpio \
                        gcc-multilib libc6 libc6-dev \
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
ENV KERNEL_VERSION  4.0.1

# Fetch the kernel sources
RUN curl --retry 10 https://www.kernel.org/pub/linux/kernel/v${KERNEL_VERSION%%.*}.x/linux-$KERNEL_VERSION.tar.xz | tar -C / -xJ && \
    mv /linux-$KERNEL_VERSION /linux-kernel

# http://aufs.sourceforge.net/
ENV AUFS_REPO       https://github.com/sfjro/aufs4-standalone
ENV AUFS_BRANCH     aufs4.0
ENV AUFS_COMMIT     170c7ace871c84ba70646f642003edf2d9162144
# we use AUFS_COMMIT to get stronger repeatability guarantees

# Download AUFS and apply patches and files, then remove it
RUN git clone -b "$AUFS_BRANCH" "$AUFS_REPO" aufs-standalone && \
    cd aufs-standalone && \
    git checkout $AUFS_COMMIT && \
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
ENV TCL_REPO_BASE   http://tinycorelinux.net/6.x/x86_64
ENV TCZ_DEPS        iptables \
                    iproute2 \
                    openssh openssl-1.0.0 \
                    tar \
                    gcc_libs \
                    acpid \
                    xz liblzma \
                    git expat2 libiconv libidn libgpg-error libgcrypt libssh2 \
                    nfs-utils tcp_wrappers portmap rpcbind libtirpc \
                    curl ntpclient \
                    procps glib2 libtirpc libffi fuse

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
RUN curl -L http://http.debian.net/debian/pool/main/libc/libcap2/libcap2_2.22.orig.tar.gz | tar -C / -xz && \
    cd /libcap-2.22 && \
    sed -i 's/LIBATTR := yes/LIBATTR := no/' Make.Rules && \
    sed -i 's/\(^CFLAGS := .*\)/\1 -m64/' Make.Rules && \
    make && \
    mkdir -p output && \
    make prefix=`pwd`/output install && \
    mkdir -p $ROOTFS/usr/local/lib && \
    cp -av `pwd`/output/lib64/* $ROOTFS/usr/local/lib

# Make sure the kernel headers are installed for aufs-util, and then build it
RUN cd /linux-kernel && \
    make INSTALL_HDR_PATH=/tmp/kheaders headers_install && \
    cd / && \
    git clone http://git.code.sf.net/p/aufs/aufs-util && \
    cd /aufs-util && \
    git checkout aufs4.0 && \
    CPPFLAGS="-m64 -I/tmp/kheaders/include" CLFAGS=$CPPFLAGS LDFLAGS=$CPPFLAGS make && \
    DESTDIR=$ROOTFS make install && \
    rm -rf /tmp/kheaders

# Prepare the ISO directory with the kernel
RUN cp -v /linux-kernel/arch/x86_64/boot/bzImage /tmp/iso/boot/vmlinuz64

# Download the rootfs, don't unpack it though:
RUN curl -L -o /tcl_rootfs.gz $TCL_REPO_BASE/release/distribution_files/rootfs64.gz

# Install the TCZ dependencies
RUN for dep in $TCZ_DEPS; do \
    echo "Download $TCL_REPO_BASE/tcz/$dep.tcz" &&\
        curl -L -o /tmp/$dep.tcz $TCL_REPO_BASE/tcz/$dep.tcz && \
        unsquashfs -f -d $ROOTFS /tmp/$dep.tcz && \
        rm -f /tmp/$dep.tcz ;\
    done

# get generate_cert
RUN curl -L -o $ROOTFS/usr/local/bin/generate_cert https://github.com/SvenDowideit/generate_cert/releases/download/0.1/generate_cert-0.1-linux-386/ && \
    chmod +x $ROOTFS/usr/local/bin/generate_cert

# Build VBox guest additions
# For future reference, we have to use x86 versions of several of these bits because TCL doesn't support ELFCLASS64
# (... and we can't use VBoxControl or VBoxService at all because of this)
#TEST removing the 32 bits version
# REMINDER
# mkdir x86 && tar -C x86 -xjf VBoxGuestAdditions-x86.tar.bz2 && \
# cp x86/lib/VBoxGuestAdditions/mount.vboxsf $ROOTFS/sbin/
ENV VBOX_VERSION 4.3.26
RUN mkdir -p /vboxguest && \
    cd /vboxguest && \
    \
    curl -L -o vboxguest.iso http://download.virtualbox.org/virtualbox/${VBOX_VERSION}/VBoxGuestAdditions_${VBOX_VERSION}.iso && \
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
    cp amd64/lib/VBoxGuestAdditions/mount.vboxsf $ROOTFS/sbin/

# Build VMware Tools
ENV OVT_VERSION 9.4.6-1770165

# Download and prepare ovt source
RUN mkdir -p /vmtoolsd/open-vm-tools \
    && curl -L http://downloads.sourceforge.net/open-vm-tools/open-vm-tools-$OVT_VERSION.tar.gz \
        | tar -xzC /vmtoolsd/open-vm-tools --strip-components 1

# Apply patches to make open-vm-tools compile with a recent 3.18.x kernel and
# a network script that knows how to plumb/unplumb nics on a busybox system,
# this will be removed once a new ovt version is released.
RUN cd /vmtoolsd && \
    curl -L -o open-vm-tools-3.x.x-patches.patch https://gist.github.com/frapposelli/5506651fa6f3d25d5760/raw/475f8fb2193549c10a477d506de40639b04fa2a7/open-vm-tools-3.x.x-patches.patch &&\
    patch -p1 < open-vm-tools-3.x.x-patches.patch && rm open-vm-tools-3.x.x-patches.patch

RUN dpkg --add-architecture i386 && apt-get update && apt-get install -y libfuse2 libtool autoconf \
                                                                         libglib2.0-dev libdumbnet-dev:i386 \
                                                                         libdumbnet1:i386 libfuse2:i386 libfuse-dev \
                                                                         libglib2.0-0:i386 libtirpc-dev libtirpc1:i386

# Horrible Hack
RUN ln -s /lib/i386-linux-gnu/libglib-2.0.so.0 /lib/i386-linux-gnu/libglib-2.0.so &&\
    ln -s /lib/i386-linux-gnu/libtirpc.so.1 /lib/i386-linux-gnu/libtirpc.so &&\
    ln -s /usr/lib/i386-linux-gnu/libgthread-2.0.so.0 /usr/lib/i386-linux-gnu/libgthread-2.0.so &&\
    ln -s /usr/lib/i386-linux-gnu/libgmodule-2.0.so.0 /usr/lib/i386-linux-gnu/libgmodule-2.0.so &&\
    ln -s /usr/lib/i386-linux-gnu/libgobject-2.0.so.0 /usr/lib/i386-linux-gnu/libgobject-2.0.so &&\
    ln -s /lib/i386-linux-gnu/libfuse.so.2 /lib/i386-linux-gnu/libfuse.so

# Compile open-vm-tools
RUN cd /vmtoolsd/open-vm-tools && autoreconf -i &&\
    CC="gcc -m32" CXX="g++ -m32" ./configure --host=i486-pc-linux-gnu --build=i486-pc-linux-gnu \
                --without-kernel-modules --without-pam --without-procps --without-x --without-icu &&\
    make CC="gcc -m32" CXX="g++ -m32" LIBS="-ltirpc" CFLAGS="-Wno-implicit-function-declaration" &&\
    make DESTDIR=$ROOTFS install

# Download and compile libdnet as open-vm-tools rely on it.
ENV LIBDNET libdnet-1.11

RUN mkdir -p /vmtoolsd/${LIBDNET} &&\
    curl -L http://sourceforge.net/projects/libdnet/files/libdnet/${LIBDNET}/${LIBDNET}.tar.gz \
        | tar -xzC /vmtoolsd/${LIBDNET} --strip-components 1 &&\
    cd /vmtoolsd/${LIBDNET} && ./configure --build=i486-pc-linux-gnu &&\
    make CC="gcc -m32" CXX="g++ -m32" &&\
    make install && make DESTDIR=$ROOTFS install

RUN cd $ROOTFS && cd usr/local/lib && ln -s libdnet.1 libdumbnet.so.1

# Make sure that all the modules we might have added are recognized (especially VBox guest additions)
RUN depmod -a -b $ROOTFS $KERNEL_VERSION-boot2docker

COPY VERSION $ROOTFS/etc/version
RUN cp -v $ROOTFS/etc/version /tmp/iso/version

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

# Dirty hack: copy /usr/local/etc/ssh/ssh_config_example into /usr/local/etc/ssh/ssh_config.example
RUN cp $ROOTFS/usr/local/etc/ssh/ssh_config_example $ROOTFS/usr/local/etc/ssh/ssh_config.example

# Dirty hack to allow SSH to use specific environment variables
RUN echo "PermitUserEnvironment yes" >> $ROOTFS/usr/local/etc/ssh/sshd_config_example
RUN cp $ROOTFS/usr/local/etc/ssh/sshd_config_example $ROOTFS/usr/local/etc/ssh/sshd_config.example

# Install Tiny Core Linux rootfs
RUN cd $ROOTFS && zcat /tcl_rootfs.gz | cpio -f -i -H newc -d --no-absolute-filenames

# Copy our custom rootfs
COPY rootfs/rootfs $ROOTFS

# Build the Hyper-V KVP Daemon
RUN cd /linux-kernel && \
    make headers_install INSTALL_HDR_PATH=/usr && \
    cd /linux-kernel/tools/hv && \
    sed -i 's/\(^CFLAGS = .*\)/\1 -m64/' Makefile && \
    make hv_kvp_daemon && \
    cp hv_kvp_daemon $ROOTFS/usr/sbin

# These steps can only be run once, so can't be in make_iso.sh (which can be run in chained Dockerfiles)
# see https://github.com/boot2docker/boot2docker/blob/master/doc/BUILD.md

# Make sure init scripts are executable
RUN find $ROOTFS/etc/rc.d/ $ROOTFS/usr/local/etc/init.d/ -exec chmod +x '{}' ';'

# Change MOTD
RUN mv $ROOTFS/usr/local/etc/motd $ROOTFS/etc/motd

# Dirty hack to make the bootscript add an environment file to the .ssh/ directory
RUN echo "touch /home/docker/.ssh/environment" >> $ROOTFS/bootscript.sh
RUN echo "echo \"PATH=/usr/local/sbin:/usr/bin:/bin:/usr/sbin:/sbin:/usr/local/bin\" >> /home/docker/.ssh/environment" >> $ROOTFS/bootscript.sh
RUN echo "touch ./executed.log" >> $ROOTFS/bootscript.sh

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
	echo 'ttyS1:2345:respawn:/sbin/getty -l /usr/local/bin/autologin 9600 ttyS0 vt100' >> $ROOTFS/etc/inittab

# fix "su -"
RUN echo root > $ROOTFS/etc/sysconfig/superuser

# crontab
COPY rootfs/crontab $ROOTFS/var/spool/cron/crontabs/root

# Copy boot params
COPY rootfs/isolinux /tmp/iso/boot/isolinux

COPY rootfs/make_iso.sh /

RUN /make_iso.sh

CMD ["cat", "boot2docker.iso"]
