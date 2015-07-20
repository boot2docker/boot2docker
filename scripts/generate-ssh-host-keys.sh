#!/bin/sh
set -e

# http://anonscm.debian.org/cgit/pkg-ssh/openssh.git/tree/debian/openssh-server.postinst?id=c77724ca2355dec905cfa1e18930c79e32db2d4e

target='/etc/ssh'
symlinkTarget=

dataMountPoint='/mnt/data'
if [ -d "$dataMountPoint$target" ]; then
	symlinkTarget="$target"
	target="$dataMountPoint$target"
fi

# generate SSH2 host keys, but only if they don't exist
for type in rsa dsa ecdsa ed25519; do
	fn="ssh_host_${type}_key"
	f="$target/ssh_host_${type}_key"
	if [ "$symlinkTarget" ]; then
		ln -sfT "$f" "$symlinkTarget/$fn"
	fi
	if [ -s "$f" ]; then
		echo "SSH2 '$type' key ($f) already exists; not regenerating."
		continue
	fi

	echo "Generating SSH2 '$type' key ($f); this may take some time..."
	yes | ssh-keygen -q -f "$f" -N '' -t "$type"
	yes | ssh-keygen -l -f "${f}.pub"
done
