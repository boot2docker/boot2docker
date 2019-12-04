#!/usr/bin/env bash
set -Eeuo pipefail

# TODO http://distro.ibiblio.org/tinycorelinux/latest-x86_64
major='10.x'
version='10.1' # TODO auto-detect latest
# 9.x doesn't seem to use ".../archive/X.Y.Z/..." in the same way as 8.x :(

mirrors=(
	http://distro.ibiblio.org/tinycorelinux
	http://repo.tinycorelinux.net
)

# https://www.kernel.org/
kernelBase='4.19'
# https://github.com/boot2docker/boot2docker/issues/1398
# https://download.virtualbox.org/virtualbox/
vboxBase='5'

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
	local file
	for file; do
		local mirror
		for mirror in "${mirrors[@]}"; do
			if wget -qO- "$mirror/$major/$file"; then
				return 0
			fi
		done
	done
	return 1
}

arch='x86_64'
rootfs='rootfs64.gz'

rootfsMd5="$(
# 9.x doesn't seem to use ".../archive/X.Y.Z/..." in the same way as 8.x :(
	fetch \
		"$arch/archive/$version/distribution_files/$rootfs.md5.txt" \
		"$arch/release/distribution_files/$rootfs.md5.txt"
)"
rootfsMd5="${rootfsMd5%% *}"
seds+=(
	-e 's/^ENV TCL_ROOTFS.*/ENV TCL_ROOTFS="'"$rootfs"'" TCL_ROOTFS_MD5="'"$rootfsMd5"'"/'
)

kernelVersion="$(
	wget -qO- 'https://www.kernel.org/releases.json' \
		| jq -r --arg base "$kernelBase" '.releases[] | .version | select(startswith($base + "."))'
)"
seds+=(
	-e 's!^(ENV LINUX_VERSION).*!\1 '"$kernelVersion"'!'
)

#vboxVersion="$(wget -qO- 'https://download.virtualbox.org/virtualbox/LATEST-STABLE.TXT')"
vboxVersion="$(
	wget -qO- 'https://download.virtualbox.org/virtualbox/' \
		| grep -oE 'href="[0-9.]+/?"' \
		| cut -d'"' -f2 | cut -d/ -f1 \
		| grep -E "^$vboxBase[.]" \
		| tail -1
)"
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

# PARALLELS_VERSION: https://github.com/boot2docker/boot2docker/pull/1332#issuecomment-420273330

# TODO figure out what's up with 7.14.0 and why it fails to build
xenVersion="$(
	git ls-remote --tags 'https://github.com/xenserver/xe-guest-utilities.git' \
		| cut -d/ -f3 \
		| cut -d^ -f1 \
		| grep -E '^v[0-9]+' \
		| cut -dv -f2- \
		| grep -E '^7[.]13[.]' \
		| sort -rV \
		| head -1
)"
seds+=(
	-e 's!^(ENV XEN_VERSION).*!\1 '"$xenVersion"'!'
)

set -x
sed -ri "${seds[@]}" Dockerfile
