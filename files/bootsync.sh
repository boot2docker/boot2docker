#!/bin/sh

/etc/init.d/autoformat start
mkdir -p /var/lib/boot2docker
chown docker:docker /var/lib/boot2docker

# make sure "/var/lib/boot2docker/etc" exists for docker-machine to write into and read "hostname" from it if it exists from a previous boot
# https://github.com/docker/machine/blob/7a9ce457496353549916e840874012a97e3d2782/libmachine/provision/boot2docker.go#L113
mkdir -p /var/lib/boot2docker/etc
if [ -s /var/lib/boot2docker/etc/hostname ]; then
	hostname="$(cat /var/lib/boot2docker/etc/hostname)"
	sethostname "$hostname"
fi

cgroupfs-mount

mkdir -p /var/lib/boot2docker/log
chown docker /var/lib/boot2docker/log

# wouldn't it be great if ntpd had a "log to XYZ file" option? (like crond does!)
ntpd -d -n -q >> /var/lib/boot2docker/log/ntp.log 2>&1
ntpd -d -n >> /var/lib/boot2docker/log/ntp.log 2>&1 &

# install certs from "/var/lib/boot2docker/certs"
for f in /var/lib/boot2docker/certs/*.pem /var/lib/boot2docker/certs/*.crt; do
	[ -e "$f" ] || continue
	# /usr/local/share/ca-certificates/**.crt gets loaded by "update-ca-certificates"
	targetFile="/usr/local/share/ca-certificates/boot2docker/$(basename "$f")"
	if [ "$targetFile" = "${targetFile%.crt}" ]; then
		targetFile="$targetFile.crt"
	fi
	mkdir -p "$(dirname "$targetFile")"
	ln -sfT "$f" "$targetFile"
done
if [ -d /usr/local/share/ca-certificates/boot2docker ]; then
	/usr/local/tce.installed/ca-certificates
fi

if [ -f /var/lib/boot2docker/profile ]; then
	. /var/lib/boot2docker/profile
fi

crond -L /var/lib/boot2docker/log/crond.log

/etc/init.d/vbox start
if grep -qi vmware /sys/class/dmi/id/sys_vendor 2>/dev/null; then
	# try to mount the root shared folder; this command can fail (if shared folders are disabled on the host, vmtoolsd will take care of the mount if they are enabled while the machine is running)
	[ -d /mnt/hgfs ] || { mkdir -p /mnt/hgfs; vmhgfs-fuse -o allow_other .host:/ /mnt/hgfs; }
	vmtoolsd --background /var/run/vmtoolsd.pid
	# TODO evaluate /usr/local/etc/init.d/open-vm-tools further (does more than this short blurb, and doesn't invoke vmhgfs-fuse)
fi
if modprobe hv_utils > /dev/null 2>&1; then
	hv_kvp_daemon
fi
/usr/local/etc/init.d/prltoolsd start
/etc/init.d/xe-linux-distribution start

if [ -d /var/lib/boot2docker/ssh ]; then
	rm -rf /usr/local/etc/ssh
else
	mv /usr/local/etc/ssh /var/lib/boot2docker/
fi
ln -sT /var/lib/boot2docker/ssh /usr/local/etc/ssh
for keyType in rsa dsa ecdsa ed25519; do # pre-generate a few SSH host keys to decrease the verbosity of /usr/local/etc/init.d/openssh
	keyFile="/usr/local/etc/ssh/ssh_host_${keyType}_key"
	[ ! -f "$keyFile" ] || continue
	echo "Generating $keyFile"
	ssh-keygen -q -t "$keyType" -N '' -f "$keyFile"
done
/usr/local/etc/init.d/openssh start

/usr/local/etc/init.d/acpid start

if [ -e /var/lib/boot2docker/bootsync.sh ]; then
	sh /var/lib/boot2docker/bootsync.sh
fi

# "env -i" thanks to https://github.com/moby/moby/issues/39009 ...
env -i PATH="$PATH" /etc/init.d/docker start

if [ -e /var/lib/boot2docker/bootlocal.sh ]; then
	sh /var/lib/boot2docker/bootlocal.sh &
fi

/opt/bootlocal.sh &
