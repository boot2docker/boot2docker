FROM ubuntu:12.04
MAINTAINER Steeve Morin "steeve.morin@gmail.com"

ENV KERNEL_VERSION  3.13.3
ENV AUFS_BRANCH     aufs3.13

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


# Fetch the kernel sources
RUN curl https://www.kernel.org/pub/linux/kernel/v3.x/linux-$KERNEL_VERSION.tar.xz | tar -C / -xJ && \
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

ADD kernel_config /linux-kernel/.config

RUN jobs=$(nproc); \
    cd /linux-kernel && \
    make -j ${jobs} oldconfig && \
    make -j ${jobs} bzImage && \
    make -j ${jobs} modules
