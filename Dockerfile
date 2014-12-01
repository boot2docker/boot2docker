FROM debian:jessie

RUN mkdir -p /tmp/iso/live /tmp/iso/isolinux

RUN apt-get update \
	&& apt-get install -y --no-install-recommends \
		aufs-tools \
		bash-completion \
		btrfs-tools \
		busybox \
		ca-certificates \
		dbus \
		ifupdown \
		iptables \
		isc-dhcp-client \
		linux-image-3.16.0-4-amd64 \
		live-boot \
		openssh-server \
		rsync \
		sudo \
		\
		squashfs-tools \
		xorriso \
		\
		isolinux \
		syslinux-common \
	&& rm -rf /var/lib/apt/lists/* \
	&& rm -rf /etc/ssh/ssh_host_* \
	&& ln -L /usr/lib/ISOLINUX/isolinux.bin /usr/lib/syslinux/modules/bios/* /tmp/iso/isolinux/ \
	&& ln -L /usr/lib/ISOLINUX/isohdpfx.bin /tmp/ \
	&& apt-get purge -y --auto-remove \
		isolinux \
		syslinux-common \
	&& ln -L /vmlinuz /initrd.img /tmp/iso/live/

#		curl \
#		wget \
#		firmware-linux-free \

# BUSYBOX ALL UP IN HERE
RUN set -e \
	&& busybox="$(which busybox)" \
	&& for m in $("$busybox" --list); do \
		if ! command -v "$m" > /dev/null; then \
			ln -vL "$busybox" /usr/local/bin/"$m"; \
		fi; \
	done

# live-boot's early-init scripts expect this to exist (and live-boot is what fixes up our initrd to work by adding some scripts that help with early-boot)
RUN mkdir -p /etc/fstab.d

# if /etc/machine-id is empty, systemd will generate a suitable ID on boot
RUN echo -n > /etc/machine-id

# setup networking (hack hack hack)
# TODO find a better way to do this natively via some eth@.service magic (like the getty magic) and remove ifupdown completely
RUN for iface in eth0 eth1 eth2 eth3; do \
		{ \
			echo "auto $iface"; \
			echo "allow-hotplug $iface"; \
			echo "iface $iface inet dhcp"; \
		} > /etc/network/interfaces.d/$iface; \
	done

# COLOR PROMPT BABY
RUN sed -ri 's/^#(force_color_prompt=)/\1/' /etc/skel/.bashrc \
	&& cp /etc/skel/.bashrc /root/

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
	} > /etc/systemd/system/getty@tty1.service.d/autologin.conf
RUN mkdir -p /etc/systemd/system/serial-getty@ttyS0.service.d && { \
		echo '[Service]'; \
		echo 'ExecStart='; \
		echo 'ExecStart=-/sbin/agetty --autologin docker --keep-baud 115200,38400,9600 %I $TERM'; \
	} > /etc/systemd/system/serial-getty@ttyS0.service.d/autologin.conf

# DOCKER DOCKER DOCKER
ENV DOCKER_VERSION 1.3.2
COPY docker-${DOCKER_VERSION} /usr/local/bin/docker
# TODO figure out why Docker panics the kernel
#COPY docker.service /etc/systemd/system/

# PURE VANITY
RUN { echo; echo 'Docker (\\s \\m \\r) [\\l]'; echo; } > /etc/issue \
	&& { echo; docker -v; echo; } > /etc/motd

# /etc/hostname, /etc/hosts, and /etc/resolv.conf are all bind-mounts in Docker, so we have to set them up in the same run step as mksquashfs or the changes won't stick
COPY excludes /tmp/
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
	&& mksquashfs / /tmp/iso/live/filesystem.squashfs \
		-comp xz -b 1M -Xdict-size '100%' \
		-wildcards -ef /tmp/excludes

# add back some of the dirs we purged so the system boots properly
RUN mkdir -p /tmp/fsappend \
	&& cd /tmp/fsappend \
	&& mkdir -p proc sys tmp
RUN mksquashfs /tmp/fsappend /tmp/iso/live/filesystem.squashfs

COPY isolinux.cfg /tmp/iso/isolinux/

RUN xorriso \
		-as mkisofs \
		-A 'Docker' \
		-V "Docker v$DOCKER_VERSION" \
		-l -J -rock -joliet-long \
		-isohybrid-mbr /tmp/isohdpfx.bin \
		-partition_offset 16 \
		-b isolinux/isolinux.bin \
		-c isolinux/boot.cat \
		-no-emul-boot \
		-boot-load-size 4 \
		-boot-info-table \
		-o /tmp/docker.iso \
		/tmp/iso
