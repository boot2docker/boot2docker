boot2docker
===========

boot2docker is a lightweight Linux distribution based on [Tiny Core Linux](http://tinycorelinux.net) made specifically to run Docker containers.
It runs completely from RAM, weighs ~23MB and boots in ~5-6s (YMMV).

Download
--------
Head over to the [Releases Page](https://github.com/steeve/boot2docker/releases) to grab the ISO.

To 'install' the ISO onto an SD card, USB-Stick or even empty hard disk, you can use ``dd if=boot2docker.iso of=/dev/sdX``.
This will create the small boot partition, and install an MBR.

How to use
----------
Simply boot from the ISO, and you're done. It runs on VMs and bare-metal machines.

If you want your containers to persist accross reboots, just attach an ext4 formatted disk to your VM, and boot2docker will automount it on `/var/lib/docker`. It will also persist the SSH keys of the machine.

boot2docker auto logs in, but if you want to SSH into the machine, the credentials are:
```
    login: docker
    pass: tcuser
```

Demo
----
http://www.youtube.com/watch?v=QzfddDvNVv0
[![boot2docker Demo Video](http://i.ytimg.com/vi/QzfddDvNVv0/maxresdefault.jpg)](http://www.youtube.com/watch?v=QzfddDvNVv0&hd=1)




Features
--------
* Kernel 3.12.1 with AUFS
* Docker 0.7
* LXC 1.0-alpha2
* Container persistance via disk automount on `/var/lib/docker`
* SSH keys persistance via disk automount


How to build
------------

boot2docker is built with Docker, via Dockerfiles.

It is composed in three disctinct steps:
* `base`: fetches, patches with AUFS support and builds the 3.12.1 Linux Kernel with Tiny Core base configuration
* `rootfs`: builds the base rootfs for boot2docker (not complete)
* running `rootfs`: when you run this image, it will build the rootfs, download the latest Docker release and create the `.iso` file on `/` of the container. This way you can update Docker without having to completely rebuild everything.

So the build process goes like this:
```
    $ sudo docker build -t boot2docker-base base/
    $ sudo docker build -t boot2docker rootfs/
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

FAQ
----

**Why not CoreOS?**

I got asked that question a lot, so I thought I should put it here once and for all. CoreOS is targeted at building infrastructure and distributed systems. I just wanted the fastest way to boot to Docker.
