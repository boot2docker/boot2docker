How to build boot2docker locally
================================

boot2docker is built with Docker, via Dockerfiles.

It is composed in three distinct steps:

* `base`: fetches, patches with AUFS support and builds the 3.14.0 Linux Kernel with Tiny Core base configuration
* `rootfs`: builds the base rootfs for boot2docker (not complete)
* running `rootfs`: when you run this image, it will build the rootfs, download the latest Docker release and create the `.iso` file on `/` of the container.

So the full build process goes like this:

```
$ sudo docker build -t boot2docker/boot2docker:base base/
$ sudo docker build -t boot2docker/boot2docker-rootfs rootfs/
$ sudo docker rm build-boot2docker
# you will need more than 2GB memory for the next step
$ sudo docker run --privileged --name build-boot2docker boot2docker/boot2docker-rootfs
$ sudo docker cp build-boot2docker:/boot2docker.iso .
$ sudo docker cp build-boot2docker:/linux-kernel/.config .
$ mv .config base/kernel_config
```

Now you can install the iso to a USB drive, SD card, CD-Rom or hard-disk. The image contains
a Master Boot Record, and a partition table, so can be written to a raw device.

```
    sudo dd if=boot2docker.iso of=/dev/sdX
```

Making your own customised boot2docker ISO
==========================================

The boot2docker release process takes advantage of
[docker.io Trusted Builds](https://index.docker.io/u/boot2docker/) so
rather than modifying the 2 Dockerfiles and re-building from scratch,
you can make a new ``Dockerfile`` that builds ``FROM boot2docker/boot2docker-rootfs``
and then run that to generate your boot2docker.iso file:


```
$ sudo docker pull boot2docker/boot2docker-rootfs
$ echo "FROM boot2docker/boot2docker-rootfs" > Dockerfile
$ echo "ADD . /data/" >> Dockerfile
$ echo "RUN somescript.sh" > Dockerfile

$ sudo docker build -t my-boot2docker-img .
$ sudo docker rm my-boot2docker
$ sudo docker run --privileged -name my-boot2docker my-boot2docker-img
$ sudo docker cp my-boot2docker:/boot2docker.iso .

```
