#!/bin/bash
set -e

preferLabel='data'
mountPoint='/mnt/data'

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

	if [ ! -d "$mountPoint/home/docker" ]; then
		# if we don't have a /home/docker yet, let's pre-seed it with our current /home/docker content
		mkdir -p "$mountPoint/home/docker"
		rsync -aq /home/docker/ "$mountPoint/home/docker/"
	fi
	rm -rf /home/docker
	ln -sfT "$mountPoint/home/docker" /home/docker
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

		mkfs.ext4 -L "$preferLabel" "${drive}1"
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
