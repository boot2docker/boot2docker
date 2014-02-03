FROM ubuntu
MAINTAINER Steeve Morin "steeve.morin@gmail.com"

# make sure the package repository is up to date
RUN echo "deb http://archive.ubuntu.com/ubuntu precise main universe" > /etc/apt/sources.list
RUN apt-get update

RUN apt-get -y install  unzip \
                        xz-utils \
                        curl \
                        bc \
                        git \
                        build-essential \
                        gcc-multilib libc6-i386 libc6-dev-i386

# Fetch the kernel 3.13 sources
RUN curl https://www.kernel.org/pub/linux/kernel/v3.x/linux-3.13.tar.xz | tar -C / -xJ

# Download AUFS and apply patches and files, then remove it
RUN git clone git://git.code.sf.net/p/aufs/aufs3-standalone && \
    cd aufs3-standalone && \
    git checkout aufs3.x-rcN && \
    cd /linux-3.13 && \
    for patch in aufs3-kbuild aufs3-base aufs3-mmap aufs3-standalone; do \
        patch -p1 < /aufs3-standalone/$patch.patch; \
    done && \
    cp -r /aufs3-standalone/Documentation /linux-3.13 && \
    cp -r /aufs3-standalone/fs /linux-3.13 && \
    cp -r /aufs3-standalone/include/uapi/linux/aufs_type.h /linux-3.13/include/uapi/linux/

ADD kernel_config /linux-3.13/.config

RUN cd /linux-3.13 && \
    make oldconfig && \
    make bzImage && \
    make modules
