#!/bin/bash
set -e

preferLabel='data'
mountPoint='/mnt/data'
forceMkdir=(
	/etc/docker
	/home/docker
)
persist=(
	"${forceMkdir[@]}"
	/etc/default/docker
	/etc/hostname
	/etc/systemd/system/docker.service
)
mkdir -p "${forceMkdir[@]}" /etc/ssh
touch "${persist[@]}"

if [ ! -s /etc/systemd/system/docker.service ]; then
	{
		echo '[Service]'
		echo 'ExecStart='
		awk -F= '$1 == "ExecStart" { print }' /lib/systemd/system/docker.service
	} > /etc/systemd/system/docker.service
fi

mkdir -p "$mountPoint"
mountpoint "$mountPoint" &> /dev/null && exit

# find all swap partitions and swapon them
IFS=$'\n'
swaps=( $(parted -sml 2>/dev/null | awk -F ':' '$1 ~ /^\/dev\// { drive = $1 } drive && $1 ~ /^[0-9]+$/ && $5 ~ /^linux-swap/ { print drive $1 }') )
unset IFS
for swap in "${swaps[@]}"; do
	if ! grep -q "^$swap " /proc/swaps; then
		swapon "$swap"
	fi
done

post_mount() {
	if /etc/init.d/docker status &> /dev/null; then
		echo >&2 'warning: Docker is running;'
		echo >&2 '  cautiously avoiding replacing the existing /var/lib/docker with a symlink'
	else
		mkdir -p "$mountPoint/var/lib/docker"
		rm -rf /var/lib/docker
		ln -sfT "$mountPoint/var/lib/docker" /var/lib/docker
	fi

	mkdir -p "$mountPoint/etc/ssh"

	for f in "${persist[@]}"; do
		t="$mountPoint$f"
		if [ ! -e "$t" ]; then
			mkdir -p "$(dirname "$t")"
			mv -T "$f" "$t"
		fi
		rm -rf "$f"
		ln -sfT "$t" "$f"
	done
	sync

	# make sure changes to /etc/systemd/system take effect
	systemctl daemon-reload || true
	# (only matters on systemd, of course)

	# TODO figure out why "X-Start-Before:" of "hostname", "hostname.sh", and/or "systemd-hostnamed" have no effect and we have to have this little hack
	host="$(cat /etc/hostname)"
	hostname "$host"
	if [ "$host" != 'docker' ]; then
		sedEscapedHost="$(echo "$host" | sed 's/[\/&]/\\&/g')"
		sed -ri 's/\bdocker\b/'"$sedEscapedHost"'/g' /etc/hosts
	fi
}

if [ -e "/dev/disk/by-label/$preferLabel" ]; then
	# if the label we want already exists in a partition, mount it
	if mount "/dev/disk/by-label/$preferLabel" "$mountPoint"; then
		post_mount
		exit
	fi
fi

# get a list of drives in the system, sorted largest first
IFS=$'\n'
drives=( $(parted -sml 2>/dev/null | awk -F ':' '$1 ~ /^\/dev\// { print $2, $1 }' | sort -rh | cut -d' ' -f2) )
unset IFS

# if any of the drives is unpartitioned, let's partition the largest unpartitioned one the way we like it
for drive in "${drives[@]}"; do
	if [ -z "$(blkid "$drive")" ]; then
		# must be unformatted!

		{
			# Add a swap partition (so Docker doesn't complain about it missing)
			echo n
			echo p
			echo 2
			echo
			echo +1000M
			echo t
			echo 82

			# Add the data partition
			echo n
			echo p
			echo 1
			echo
			echo

			echo w
		} | fdisk "$drive"

		mkswap "${drive}2"
		swapon "${drive}2"

		# overlayfs is a bit of an inode snob, so we set bytes-per-inode to half the usual default of roughly 16384
		# http://stackoverflow.com/a/5425321/433558
		mkfs.ext4 -i 8192 -L "$preferLabel" "${drive}1"
		mount "${drive}1" "$mountPoint"
		post_mount
		exit
	fi
done
# we failed all the easy ways, so let's get creative

# get a list of partitions on the system, sorted largest first (filtering down to just "ext*" and "btrfs" partitions so there's a chance of Docker compatibility)
IFS=$'\n'
partitions=( $(parted -sml 2>/dev/null | awk -F ':' '$1 ~ /^\/dev\// { drive = $1 } drive && $1 ~ /^[0-9]+$/ && $5 ~ /^ext|^btrfs$/ { print $4, drive $1 }' | sort -rh | cut -d' ' -f2) )
unset IFS

for partition in "${partitions[@]}"; do
	if mount "$partition" "$mountPoint"; then
		# success! (ish)
		post_mount
		exit
	fi
done

echo >&2 'warning: no data drive candidates found'
exit 1
