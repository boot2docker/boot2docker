Description: replace "mount" with "unsquashfs" and ignore "-KERNEL" deps
Author: Tatsushi Demachi, Tianon Gravi
Partial-Origin: https://github.com/tatsushid/docker-tinycore/blob/017b258a08a41399f65250c9865a163226c8e0bf/8.2/x86_64/src/tce-load.patch
Unpatched-Source: https://github.com/tinycorelinux/Core-scripts/blob/19fed4fa59585899ef47163424b15f59f15d3e4d/usr/bin/tce-load

diff --git a/usr/bin/tce-load b/usr/bin/tce-load
index 1378b90..fea2aa8 100755
--- a/usr/bin/tce-load
+++ b/usr/bin/tce-load
@@ -81,15 +81,15 @@ fetch_app() {
 
 copyInstall() {
 	[ -d /mnt/test ] || sudo /bin/mkdir -p /mnt/test
-	sudo /bin/mount $1 /mnt/test -t squashfs -o loop,ro,bs=4096
+	sudo /usr/local/bin/unsquashfs -force -dest /mnt/test $1 || exit 1
 	if [ "$?" == 0 ]; then
 		if [ "$(ls -A /mnt/test)" ]; then
 			yes "$FORCE" | sudo /bin/cp -ai /mnt/test/. / 2>/dev/null
 			[ -n "`find /mnt/test/ -type d -name modules`" ] && MODULES=TRUE
 		fi
-		sudo /bin/umount -d /mnt/test
+		sudo rm -rf /mnt/test
 	fi
-	[ "$BOOTING" ] || rmdir /mnt/test
+	[ "$BOOTING" ] || [ -d /mnt/test ] && rmdir /mnt/test
 }

 update_system() {
@@ -161,8 +161,8 @@ recursive_scan_dep() {
 	echo -e "$@"|awk '
 	function recursive_scan(name, optional, mirror, _, depfile, line, i) {
 		gsub(/[\t ]+/, "", name)
-		if (name) {
-			sub(/\-KERNEL\.tcz/, "-"KERNELVER".tcz", name)
+		# in boot2docker, we install a custom kernel, so ignore "xyz-KERNEL" dependencies
+		if (name && name !~ /\-KERNEL\.tcz/) {
 			if (name in MARK) {
 				if (MARK[name] == 2) {
 					if (! SUPPRESS)
@@ -225,7 +225,7 @@ FROMWHERE=""
 for TARGETAPP in $@; do
 
 TARGETAPP="${TARGETAPP%.tcz}.tcz"
-TARGETAPP="${TARGETAPP/-KERNEL.tcz/-${KERNELVER}.tcz}"
+[ "$TARGETAPP" = "${TARGETAPP/-KERNEL.tcz/}" ] || continue # in boot2docker, we install a custom kernel, so ignore "xyz-KERNEL" dependencies
 EXTENSION="${TARGETAPP##*/}"
 APPNAME="${EXTENSION%.*}"
 
