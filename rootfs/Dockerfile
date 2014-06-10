#  docker build  --rm -t my-boot2docker-img . && docker run --rm my-boot2docker-img > /tmp/boot2docker.iso
FROM boot2docker/boot2docker
ADD ./rootfs/ /rootfs
ADD ./make_iso.sh /
RUN chmod +x /rootfs/etc/rc.d/*  && chmod +x //rootfs/usr/local/etc/init.d/* && chmod +x /rootfs/*.sh && /make_iso.sh
CMD ["cat", "boot2docker.iso"]
