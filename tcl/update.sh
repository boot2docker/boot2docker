#!/usr/bin/env bash
set -Eeuo pipefail

# TODO http://distro.ibiblio.org/tinycorelinux/latest-x86_64
major='8.x'
version='8.2.1' # TODO auto-detect latest
# 9.x doesn't seem to use ".../archive/X.Y.Z/..." in the same way as 8.x :(

packages=(
	# needed for "tce-load.patch"
	squashfs-tools.tcz

	# required for Docker, deps on "xyz-KERNEL.tcz"
	#iptables.tcz
	# fixed via tce-load patch instead (more sustainable)
)

mirrors=(
	http://distro.ibiblio.org/tinycorelinux
	http://repo.tinycorelinux.net
)

kernelBase='4.9'

# avoid issues with slow Git HTTP interactions (*cough* sourceforge *cough*)
export GIT_HTTP_LOW_SPEED_LIMIT='100'
export GIT_HTTP_LOW_SPEED_TIME='2'
# ... or servers being down
wget() { command wget --timeout=2 "$@" -o /dev/null; }

cd "$(dirname "$(readlink -f "$BASH_SOURCE")")"

seds=(
	-e 's!^(ENV TCL_MIRRORS).*!\1 '"${mirrors[*]}"'!'
	-e 's!^(ENV TCL_MAJOR).*!\1 '"$major"'!'
	-e 's!^(ENV TCL_VERSION).*!\1 '"$version"'!'
)

fetch() {
	local mirror
	for mirror in "${mirrors[@]}"; do
		if wget -qO- "$mirror/$major/$1"; then
			return 0
		fi
	done
	return 1
}

arch='x86_64'
rootfs='rootfs64.gz'

rootfsMd5="$(fetch "$arch/archive/$version/distribution_files/$rootfs.md5.txt")"
rootfsMd5="${rootfsMd5%% *}"
seds+=(
	-e 's/^ENV TCL_ROOTFS.*/ENV TCL_ROOTFS="'"$rootfs"'" TCL_ROOTFS_MD5="'"$rootfsMd5"'"/'
)

archPackages=()
archPackagesMd5s=()
declare -A seen=()
set -- "${packages[@]}"
while [ "$#" -gt 0 ]; do
	package="$1"; shift
	[ -z "${seen[$package]:-}" ] || continue
	seen[$package]=1

	packageMd5="$(fetch "$arch/tcz/$package.md5.txt")"
	packageMd5="${packageMd5%% *}"

	archPackages+=( "$package" )
	archPackagesMd5s+=(
		'TCL_PACKAGE_MD5__'"$(echo "$package" | sed -r 's/[^a-zA-Z0-9]+/_/g')"'="'"$packageMd5"'"'
	)

	if packageDeps="$(
		fetch "$arch/tcz/$package.dep" \
			| grep -vE -- '-KERNEL'
	)"; then
		set -- $packageDeps "$@"
	fi
done
seds+=(
	-e 's!^ENV TCL_PACKAGES.*!ENV TCL_PACKAGES="'"${archPackages[*]}"'" '"${archPackagesMd5s[*]}"'!'
)

kernelVersion="$(
	wget -qO- 'https://www.kernel.org/releases.json' \
		| jq -r --arg base "$kernelBase" '.releases[] | .version | select(startswith($base + "."))'
)"
seds+=(
	-e 's!^(ENV LINUX_VERSION).*!\1 '"$kernelVersion"'!'
)

aufsBranch="aufs$kernelBase"
aufsCommit="$(
	git ls-remote 'https://github.com/sfjro/aufs4-standalone.git' "refs/heads/$aufsBranch" \
		| cut -d$'\t' -f1
)"
seds+=(
	-e 's!^(ENV AUFS_BRANCH).*!\1 '"$aufsBranch"'!'
	-e 's!^(ENV AUFS_COMMIT).*!\1 '"$aufsCommit"'!'
)
aufsUtilBranch="$aufsBranch"
aufsUtilCommit="$(
	{
		git ls-remote 'https://git.code.sf.net/p/aufs/aufs-util' "refs/heads/$aufsUtilBranch" \
			|| git ls-remote 'https://github.com/tianon/aufs-util.git' "refs/heads/$aufsUtilBranch"
	} | cut -d$'\t' -f1
)"
seds+=(
	-e 's!^(ENV AUFS_UTIL_BRANCH).*!\1 '"$aufsUtilBranch"'!'
	-e 's!^(ENV AUFS_UTIL_COMMIT).*!\1 '"$aufsUtilCommit"'!'
)

vboxVersion="$(wget -qO- 'https://download.virtualbox.org/virtualbox/LATEST-STABLE.TXT')"
vboxSha256="$(
	{
		wget -qO- "https://download.virtualbox.org/virtualbox/$vboxVersion/SHA256SUMS" \
		|| wget -qO- "https://www.virtualbox.org/download/hashes/$vboxVersion/SHA256SUMS"
	} | awk '$2 ~ /^[*]?VBoxGuestAdditions_.*[.]iso$/ { print $1 }'
)"
seds+=(
	-e 's!^(ENV VBOX_VERSION).*!\1 '"$vboxVersion"'!'
	-e 's!^(ENV VBOX_SHA256).*!\1 '"$vboxSha256"'!'
)

# TODO PARALLELS_VERSION ??

xenVersion="$(
	git ls-remote --tags 'https://github.com/xenserver/xe-guest-utilities.git' \
		| cut -d/ -f3 \
		| cut -d^ -f1 \
		| grep -E '^v[0-9]+' \
		| cut -dv -f2- \
		| sort -rV \
		| head -1
)"
seds+=(
	-e 's!^(ENV XEN_VERSION).*!\1 '"$xenVersion"'!'
)

set -x
sed -ri "${seds[@]}" Dockerfile
