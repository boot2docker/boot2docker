boot2docker
===========

boot2docker is a lightweight Linux distribution based on [Tiny Core Linux](http://tinycorelinux.net) made specifically to run [Docker](https://www.docker.io/) containers. It runs completely from RAM, weighs ~27MB and boots in ~5s (YMMV). The [ISO can be download here](https://github.com/steeve/boot2docker/releases). To see boot2docker in action look at this [demo](http://www.youtube.com/watch?v=QzfddDvNVv0).


## Features
* Kernel 3.12.1 with AUFS, Docker 0.8.0, LXC 0.8.0
* Container persistence via disk automount on `/var/lib/docker`
* SSH keys persistence via disk automount


## Installation

#### OSX
```
$ brew install boot2docker
```

#### Linux/Unix
```
$ curl https://raw.github.com/steeve/boot2docker/master/boot2docker > boot2docker
$ chmod +x boot2docker
```


## How to use
boot2docker comes with a simple init script that leverage's VirtualBox's `VBoxManage`. You can start, stop and delete the VM right from the command line.

#### Initialize
```
$ boot2docker init
```

#### Start vm
```
$ boot2docker up
```


## Advanced usage

#### Customize
You can customise the values of *VM_NAME*, *DOCKER_PORT*, *SSH_HOST_PORT*, *VM_DISK*, *VM_DISK_SIZE*, *VM_MEM* and *BOOT2DOCKER_ISO* by setting them in ``$HOME/.boot2docker/profile``

#### Persist data
If you want your containers to persist across reboots, attach an ext4 formatted disk with the label ``boot2docker-data`` (``mkfs.ext4 -L boot2docker-data /dev/sdX5``) to your VM, and boot2docker will automount it on `/mnt/sdX` and then softlink `/mnt/sdX/var/lib/docker` to `/var/lib/docker`. It will also persist the SSH keys of the machine.

#### SSH into VM
```
$ boot2docker ssh
```
boot2docker auto logs in, but if you want to SSH into the machine, the credentials are:
```
user: docker
pass: tcuser
```

#### Install on any device
To 'install' the ISO onto an SD card, USB-Stick or even empty hard disk, you can
use ``dd if=boot2docker.iso of=/dev/sdX``.
This will create the small boot partition, and install an MBR.