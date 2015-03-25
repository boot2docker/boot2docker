#!/bin/sh
set -e

# http://anonscm.debian.org/cgit/pkg-ssh/openssh.git/tree/debian/openssh-server.postinst?id=c77724ca2355dec905cfa1e18930c79e32db2d4e

# generate SSH2 host keys, but only if they don't exist
for type in rsa dsa ecdsa ed25519; do
	f="/etc/ssh/ssh_host_${type}_key"
	if [ -f "$f" ]; then
		echo "SSH2 '$type' key ($f) already exists; not regenerating."
		continue
	fi

	echo "Generating SSH2 '$type' key ($f); this may take some time..."
	ssh-keygen -q -f "$f" -N '' -t "$type"
	ssh-keygen -l -f "${f}.pub"
done
