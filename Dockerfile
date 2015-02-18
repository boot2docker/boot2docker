FROM debian:jessie

RUN mkdir -p /tmp/iso/isolinux

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
		openssh-server \
		rsync \
		sudo \
		\
		squashfs-tools \
		xorriso \
		xz-utils \
		\
		isolinux \
		syslinux-common \
	&& rm -rf /var/lib/apt/lists/* \
	&& rm -rf /etc/ssh/ssh_host_* \
	&& ln -L /usr/lib/ISOLINUX/isolinux.bin /usr/lib/syslinux/modules/bios/* /tmp/iso/isolinux/ \
	&& ln -L /usr/lib/ISOLINUX/isohdpfx.bin /tmp/ \
	&& apt-get purge -y --auto-remove \
		isolinux \
		syslinux-common

#		apparmor \
# see https://wiki.debian.org/AppArmor/HowTo and isolinux.cfg

#		curl \
#		wget \

# BUSYBOX ALL UP IN HERE
RUN set -e \
	&& busybox="$(which busybox)" \
	&& for m in $("$busybox" --list); do \
		if ! command -v "$m" > /dev/null; then \
			ln -vL "$busybox" /usr/local/bin/"$m"; \
		fi; \
	done

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
ENV DOCKER_VERSION 1.5.0
COPY docker-${DOCKER_VERSION} /usr/local/bin/docker
COPY docker.service /etc/systemd/system/
RUN systemctl enable docker.service

# PURE VANITY
RUN { echo; echo 'Docker (\\s \\m \\r) [\\l]'; echo; } > /etc/issue \
	&& { echo; docker -v; echo; } > /etc/motd

COPY isolinux.cfg /tmp/iso/isolinux/

COPY initramfs-live-hook.sh /usr/share/initramfs-tools/hooks/live
COPY initramfs-live-script.sh /usr/share/initramfs-tools/scripts/live

COPY excludes /tmp/
COPY build-iso.sh /usr/local/bin/

RUN build-iso.sh # creates /tmp/docker.iso
