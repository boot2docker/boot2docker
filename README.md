boot2docker
===========

boot2docker is a lightweight Linux distribution based on [Tiny Core Linux](http://tinycorelinux.net) made specifically to run [Docker](https://www.docker.io/) containers.
It runs completely from RAM, weighs ~23MB and boots in ~5-6s (YMMV).

Download
--------
Head over to the [Releases Page](https://github.com/steeve/boot2docker/releases) to grab the ISO.

To 'install' the ISO onto an SD card, USB-Stick or even empty hard disk, you can use ``dd if=boot2docker.iso of=/dev/sdX``.
This will create the small boot partition, and install an MBR.

Demo
----
http://www.youtube.com/watch?v=QzfddDvNVv0
[![boot2docker Demo Video](http://i.imgur.com/hIwudK3.gif)](http://www.youtube.com/watch?v=QzfddDvNVv0&hd=1)

How to use
----------
Simply boot from the ISO, and you're done. It runs on VMs and bare-metal machines.

If you want your containers to persist across reboots, just attach an ext4 formatted disk to your VM, and boot2docker will automount it on `/var/lib/docker`. It will also persist the SSH keys of the machine.

boot2docker auto logs in, but if you want to SSH into the machine, the credentials are:
```
    login: docker
    pass: tcuser
```
Make sure to setup a port forward from host to guest port 22. Avoid bridged networking due to the static login and password.

Init Script (OSX only for now)
------------------------------
boot2docker now comes with a rather simple init script that leverage's VirtualBox's `VBoxManage`. Essentially, you can init, start, suspend and stop the boot2docker VM right from the command line.

The VM has the following specs:

* CPU Cores: same as host (physical, not logical)
* 40gb HDD
* 1gb memory
* Autoboots to boot2docker
* NAT networked (Docker `4243->4243` and SSH `22->2022` are forwarded to the host)

Beware, this is work in progress. To use:

```
$ mkdir vm
$ cd vm
$ curl https://raw.github.com/steeve/boot2docker/master/boot2docker > boot2docker
$ chmod +x boot2docker
$ ./boot2docker init
$ ./boot2docker up
$ ./boot2docker ssh
```

If `ssh` complains about the keys:

```
$ ssh-keygen -R '[localhost]:2022'
```

If you want to use the brand new Docker OSX client, you'll need to restart the Docker daemon to listen on `0.0.0.0` (which is not done yet for security reason, eventually this step should disappear):

```
$ ./boot2docker ssh
docker@boot2docker:~$ sudo /usr/local/etc/init.d/docker stop
docker@boot2docker:~$ /usr/local/bin/docker -H tcp:// -d > /var/lib/docker/docker.log 2>&1 &
docker@boot2docker:~$ exit
$ curl http://get.docker.io/builds/Darwin/x86_64/docker-0.7.3.tgz | tar xvz
$ export DOCKER_HOST=localhost
$ ./usr/local/bin/docker version
```

Features
--------
* Kernel 3.12.1 with AUFS
* Docker 0.7
* LXC 1.0-alpha2
* Container persistence via disk automount on `/var/lib/docker`
* SSH keys persistence via disk automount


How to build
------------

boot2docker is built with Docker, via Dockerfiles.

It is composed in three distinct steps:
* `base`: fetches, patches with AUFS support and builds the 3.12.1 Linux Kernel with Tiny Core base configuration
* `rootfs`: builds the base rootfs for boot2docker (not complete)
* running `rootfs`: when you run this image, it will build the rootfs, download the latest Docker release and create the `.iso` file on `/` of the container. This way you can update Docker without having to completely rebuild everything.

So the build process goes like this:
```
    # $ sudo docker build -t steeve/boot2docker-base base/
    # OR for most uses, avoid re-building and downloading lots of ubuntu packages by:
    $ sudo docker pull steeve/boot2docker-base
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

**Login as root**

Run `sudo -s` as the docker user.

**Why not CoreOS?**

I got asked that question a lot, so I thought I should put it here once and for all. [CoreOS](http://coreos.com/) is targeted at building infrastructure and distributed systems. I just wanted the fastest way to boot to Docker.
