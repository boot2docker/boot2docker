How to build
============

boot2docker is built with Docker, via Dockerfiles.

It is composed in three distinct steps:

* `base`: fetches, patches with AUFS support and builds the 3.12.1 Linux Kernel with Tiny Core base configuration
* `rootfs`: builds the base rootfs for boot2docker (not complete)
* running `rootfs`: when you run this image, it will build the rootfs, download the latest Docker release and create the `.iso` file on `/` of the container. This way you can update Docker without having to completely rebuild everything.

So the build process goes like this:

```
# $ sudo docker build -t steeve/boot2docker-base --rm base/
# OR for most uses, avoid re-building and downloading lots of ubuntu packages by:
$ sudo docker pull steeve/boot2docker-base
$ sudo docker build -t boot2docker --rm rootfs/
```

Once that's done, to build a custom `boot2docker.iso`, just run the built rootfs image:

```
$ sudo docker rm build-boot2docker
$ sudo docker run --privileged -name build-boot2docker boot2docker
$ sudo docker cp build-boot2docker:/boot2docker.iso .
```

Now you can install the iso to a USB drive, SD card, CD-Rom or hard-disk. The image contains
a Master Boot Record, and a partition table, so can be written to a raw device.

```
    sudo dd if=boot2docker.iso of=/dev/sdX
```
