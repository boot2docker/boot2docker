FROM debian:jessie

RUN apt-get update && apt-get install -y \
		aufs-tools \
		bash-completion \
		ca-certificates \
		dbus \
		iptables \
		isc-dhcp-client \
		isolinux \
		linux-image-amd64 \
		live-boot \
		makedev \
		openssh-server \
		rsync \
		squashfs-tools \
		sudo \
		syslinux-common \
		wget \
		xorriso \
		--no-install-recommends \
	&& rm -rf /var/lib/apt/lists/* \
	&& rm -rf /etc/ssh/ssh_host_*
# TODO delete a bunch of stuff inspired by debian2docker (/lib/modules is ripe for some ritual cleansing)

#		firmware-linux-free \

# undo some of the Docker-specific hack from the base image :)
RUN rm /usr/sbin/policy-rc.d

# live-boot's scripts expect this to exist (and live-boot is what fixes up our initrd to work, and adds some scripts that help with early-boot)
RUN mkdir -p /etc/fstab.d

# setup our non-root user, set passwords for both users, and setup sudo
RUN useradd --create-home --shell /bin/bash docker \
	&& { \
		echo 'root:docker'; \
		echo 'docker:docker'; \
	} | chpasswd \
	&& echo 'docker ALL=(ALL) NOPASSWD: ALL' > /etc/sudoers.d/docker

# autologin for both tty1 and ttyS0
# see also: grep ^ExecStart /lib/systemd/system/*getty@.service
RUN mkdir -p /etc/systemd/system/getty@tty1.service.d && { \
		echo '[Service]'; \
		echo 'ExecStart='; \
		echo 'ExecStart=-/sbin/agetty --autologin docker --noclear %I $TERM'; \
	} > /etc/systemd/system/getty@tty1.service.d/autologin.conf \
	&& mkdir -p /etc/systemd/system/serial-getty@ttyS0.service.d && { \
		echo '[Service]'; \
		echo 'ExecStart='; \
		echo 'ExecStart=-/sbin/agetty --autologin docker --keep-baud 115200,38400,9600 %I $TERM'; \
	} > /etc/systemd/system/serial-getty@ttyS0.service.d/autologin.conf

RUN echo 'deb http://get.docker.com/ubuntu docker main' > /etc/apt/sources.list.d/docker.list \
	&& apt-key adv --keyserver pgp.mit.edu --recv-keys 36A1D7869245C8950F966E92D8576A8BA88D21E9

ENV DOCKER_VERSION 1.3.1

RUN apt-get update && apt-get install -y lxc-docker-$DOCKER_VERSION --no-install-recommends && rm -rf /var/lib/apt/lists/*
RUN rm -v /etc/rc*/*docker*

#RUN wget "https://get.docker.com/builds/$(uname -s)/$(uname -m)/docker-${DOCKER_VERSION}" -O /usr/local/bin/docker \
#	&& chmod +x /usr/local/bin/docker

#RUN wget "https://raw.githubusercontent.com/docker/docker/v${DOCKER_VERSION}/contrib/init/sysvinit-debian/docker" -O /etc/init.d/docker \
#	&& sed -i 's!/usr/bin/!/usr/local/bin/!g' /etc/init.d/docker \
#	&& chmod +x /etc/init.d/docker \
#	&& wget "https://raw.githubusercontent.com/docker/docker/v${DOCKER_VERSION}/contrib/init/sysvinit-debian/docker.default" -O /etc/default/docker \
#	&& update-rc.d docker defaults
#RUN for f in docker.service docker.socket; do \
#		wget "https://raw.githubusercontent.com/docker/docker/v${DOCKER_VERSION}/contrib/init/systemd/$f" -O /lib/systemd/system/"$f"; \
#	done \
#	&& sed -i 's!/usr/bin/!/usr/local/bin/!g' /lib/systemd/system/docker.service \
#	&& systemctl enable docker.service

# http://l3net.wordpress.com/2013/09/21/how-to-build-a-debian-livecd/

WORKDIR /tmp/iso

RUN mkdir -p live
RUN cp -L /vmlinuz /initrd.img live/
#RUN mksquashfs / live/filesystem.squashfs -comp xz -e /.docker* boot dev initrd.img proc run sys tmp usr/share/doc usr/share/man usr/share/mime var/cache var/lock var/log vmlinuz etc/hostname
#RUN mksquashfs / live/filesystem.squashfs -comp xz -e /.docker* dev proc sys tmp etc/hostname
RUN echo 'docker' > /etc/hostname \
	&& { \
		echo '127.0.0.1   localhost docker'; \
		echo '::1         localhost ip6-localhost ip6-loopback'; \
		echo 'fe00::0     ip6-localnet'; \
		echo 'ff00::0     ip6-mcastprefix'; \
		echo 'ff02::1     ip6-allnodes'; \
		echo 'ff02::2     ip6-allrouters'; \
	} > /etc/hosts \
	&& { \
		echo 'nameserver 8.8.8.8'; \
		echo 'nameserver 8.8.4.4'; \
	} > /etc/resolv.conf \
	&& mksquashfs / live/filesystem.squashfs -comp xz -wildcards -e '.docker*' boot initrd.img proc sys tmp vmlinuz

# add back some of the stuff we purged so it boots properly
RUN mkdir -p /tmp/fsappend \
	&& cd /tmp/fsappend \
	&& mkdir -p proc sys tmp
RUN mksquashfs /tmp/fsappend live/filesystem.squashfs

RUN mkdir -p isolinux
RUN cp /usr/lib/ISOLINUX/isolinux.bin isolinux/
RUN rsync -av /usr/lib/syslinux/modules/bios/ isolinux/

COPY isolinux.cfg /tmp/iso/isolinux/

RUN xorriso \
		-as mkisofs \
		-A 'Docker' \
		-V "Docker v$DOCKER_VERSION" \
		-l -J -rock -joliet-long \
		-isohybrid-mbr /usr/lib/ISOLINUX/isohdpfx.bin \
		-partition_offset 16 \
		-b isolinux/isolinux.bin \
		-c isolinux/boot.cat \
		-no-emul-boot \
		-boot-load-size 4 \
		-boot-info-table \
		-o /tmp/docker.iso \
		.
