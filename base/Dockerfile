FROM ubuntu
MAINTAINER Steeve Morin "steeve.morin@gmail.com"

# make sure the package repository is up to date
RUN echo "deb http://archive.ubuntu.com/ubuntu precise main universe" > /etc/apt/sources.list
RUN apt-get update

RUN apt-get -y install  unzip \
                        xz-utils \
                        curl \
                        bc \
                        build-essential \
                        gcc-multilib libc6-i386 libc6-dev-i386

# Fetch the kernel 3.12.1 sources
RUN curl https://www.kernel.org/pub/linux/kernel/v3.x/linux-3.12.1.tar.xz | tar -C / -xJ

# Download AUFS and apply patches and files, then remove it
RUN curl -L -o /aufs-standalone-3.12.zip http://sourceforge.net/code-snapshots/git/a/au/aufs/aufs3-standalone.git/aufs-aufs3-standalone-4a7364f2f7c6db8bb880d7aefbeb34efc1d66ad4.zip && \
    unzip /aufs-standalone-3.12.zip && \
    rm -f /aufs-standalone-3.12.zip && \
    mv /aufs-aufs3-standalone-4a7364f2f7c6db8bb880d7aefbeb34efc1d66ad4 aufs3-standalone-3.12 && \
    cd /linux-3.12.1 && \
    for patch in aufs3-kbuild aufs3-base aufs3-mmap aufs3-standalone; do \
        patch -p1 < /aufs3-standalone-3.12/$patch.patch; \
    done && \
    cp -r /aufs3-standalone-3.12/Documentation /linux-3.12.1 && \
    cp -r /aufs3-standalone-3.12/fs /linux-3.12.1 && \
    cp -r /aufs3-standalone-3.12/include/uapi/linux/aufs_type.h /linux-3.12.1/include/uapi/linux/

ADD kernel_config /linux-3.12.1/.config

RUN cd /linux-3.12.1 && \
    make oldconfig && \
    make bzImage && \
    make modules
