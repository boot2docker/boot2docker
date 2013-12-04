boot2docker
===========

boot2docker is a lightweight Linux distribution base on [Tiny Core Linux](http://tinycorelinux.net) made specifically to run Docker containers.
It runs completely from RAM, weights ~38mb and boots in ~5-6s (YMMV).

It was made during the Global Docker Hack Day on Dec. 3, 2013.


Download
--------
Head over to the [Relases Page](https://github.com/steeve/boot2docker/releases) to grab the ISO.


How to use
----------
Simply boot from the ISO, and you're done. It runs on VMs and bare metal machines.

If you want your containers to persist accross reboots, just attach an ext4 formatted disk to your VM, and boot2docker will automount it on `/var/lib/docker`. It will also persist the SSH keys of the machine.

boot2docker auto logs in, but if you want to SSH into the machine, the credentials are:
```
login: docker
pass: tcuser
```

Demo
----
http://www.youtube.com/watch?v=Z1bQyP4-Uvc
[![boot2docker Demo Video](http://i.ytimg.com/vi/Z1bQyP4-Uvc/maxresdefault.jpg)](http://www.youtube.com/watch?v=Z1bQyP4-Uvc&hd=1)




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
$ sudo docker run --privileged boot2docker
<COTAINER_ID>
$ sudo docker cp <CONTAINER_ID>:/boot2docker.iso .
```


FAQ
----

**Why not CoreOS?**

I got asked that question a lot, so I thought I should put it here. I liked the original idea of CoreOS: the smallest possible way to boot to docker. Unfortunately CoreOS has been growing larger and seems to be reinventing the wheel on a lot of features already implemented or planned for Docker. I just wanted the fastest way to boot to Docker.
