FROM boot2docker
MAINTAINER Steeve Morin "steeve.morin@gmail.com"

# Build VBox guest additions
# For future reference, we have to use x86 versions of several of these bits because TCL doesn't support ELFCLASS64
# (... and we can't use VBoxControl or VBoxService at all because of this)
ENV VBOX_VERSION 4.3.18
RUN mkdir -p /vboxguest && \
    cd /vboxguest && \
    \
    curl -L -o vboxguest.iso http://download.virtualbox.org/virtualbox/${VBOX_VERSION}/VBoxGuestAdditions_${VBOX_VERSION}.iso && \
    7z x vboxguest.iso -ir'!VBoxLinuxAdditions.run' && \
    rm vboxguest.iso && \
    \
    sh VBoxLinuxAdditions.run --noexec --target . && \
    mkdir amd64 && tar -C amd64 -xjf VBoxGuestAdditions-amd64.tar.bz2 && \
    mkdir x86 && tar -C x86 -xjf VBoxGuestAdditions-x86.tar.bz2 && \
    rm VBoxGuestAdditions*.tar.bz2 && \
    \
    KERN_DIR=/linux-kernel/ make -C amd64/src/vboxguest-${VBOX_VERSION} && \
    cp amd64/src/vboxguest-${VBOX_VERSION}/*.ko $ROOTFS/lib/modules/$KERNEL_VERSION-tinycore64/ && \
    \
    mkdir -p $ROOTFS/sbin && \
    cp x86/lib/VBoxGuestAdditions/mount.vboxsf $ROOTFS/sbin/

# Copy our custom rootfs
COPY rootfs $ROOTFS

RUN /make_iso.sh
CMD ["cat", "/iso/boot2docker.iso"]
