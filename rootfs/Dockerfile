FROM steeve/boot2docker-base
MAINTAINER Steeve Morin "steeve.morin@gmail.com"

ENV ROOTFS          /rootfs
ENV TCL_REPO_BASE   http://tinycorelinux.net/5.x/x86
ENV TCZ_DEPS        iptables openssl-1.0.0 openssh tar gcc_libs libnl iw acpid bash ncurses-common ncurses-terminfo ncurses ncurses-utils

RUN apt-get -y install  squashfs-tools \
                        genisoimage \
                        xorriso \
                        syslinux \
                        automake \
                        pkg-config

# Make the ROOTFS
RUN mkdir -p $ROOTFS

# Install the kernel modules in $ROOTFS
RUN cd /linux-3.12.1 && \
    make INSTALL_MOD_PATH=$ROOTFS modules_install firmware_install
# Here we could remove useless modules, but we'll do that later if there is such a need.

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

ADD lxc-0.8.0-boot2docker.patch /

# Download LXC, patch it with a 0.8.0 port of @sebp's patch to properly change root from a ramdisk, compile and install
#    curl -L https://github.com/spahl/lxc/commit/d6b2904d50cac7c44e6f490308b8dd1417281529.patch | patch -p1 && 
RUN curl -L https://github.com/lxc/lxc/archive/lxc-0.8.0.tar.gz | tar -C / -xz && \
    cd /lxc-lxc-0.8.0 && \
    patch -p2 < /lxc-0.8.0-boot2docker.patch && \
    ./autogen.sh && \
    LIBCAPLIB=/libcap-2.22/output/ CFLAGS="-m32 -I${LIBCAPLIB}/include -L${LIBCAPLIB}/lib64" ./configure prefix=/usr/local --disable-apparmor --disable-bash && \
    make && \
    make prefix=$ROOTFS install && \
    mkdir -p $ROOTFS/usr/var/lib/lxc && \
    mkdir -p $ROOTFS/usr/local/lib/lxc/rootfs && \
    mkdir -p $ROOTFS/cgroup && \
    mkdir -p $ROOTFS/dev/mqueue

# Make sure the kernel headers are installed for aufs-util, and then build it
RUN cd /linux-3.12.1 && \
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
        curl -L -o /tmp/$dep.tcz $TCL_REPO_BASE/tcz/$dep.tcz && \
        unsquashfs -f -d $ROOTFS /tmp/$dep.tcz && \
        rm -f /tmp/$dep.tcz ;\
    done

# Copy over out custom rootfs
ADD rootfs $ROOTFS

# Make sure init scripts are executable
RUN find $ROOTFS/etc/rc.d/ -exec chmod +x {} \; && \
    find $ROOTFS/usr/local/etc/init.d/ -exec chmod +x {} \;

#get the latest docker
RUN curl -L -o $ROOTFS/usr/local/bin/docker https://get.docker.io/builds/Linux/x86_64/docker-latest && \
    chmod +x $ROOTFS/usr/local/bin/docker

# Download the latest Pipework
RUN curl -L -o $ROOTFS/usr/local/bin/pipework https://raw2.github.com/jpetazzo/pipework/master/pipework && \
    chmod +x $ROOTFS/usr/local/bin/pipework

ADD isolinux /isolinux
ADD make_iso.sh /

CMD ["/bin/sh", "/make_iso.sh"]
