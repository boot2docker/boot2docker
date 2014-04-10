boot2docker
===========

boot2docker is a lightweight Linux distribution based on [Tiny Core Linux](http://tinycorelinux.net) made specifically to run [Docker](https://www.docker.io/) containers. It runs completely from RAM, weighs ~24MB and boots in ~5s (YMMV). The [ISO can be download here](https://github.com/boot2docker/boot2docker/releases).

[![boot2docker Demo Video](http://i.imgur.com/hIwudK3.gif)](http://www.youtube.com/watch?v=QzfddDvNVv0&hd=1)

See [Frequently asked questions](doc/FAQ.md) for more details.

## Features
* Kernel 3.14.0 with AUFS, Docker 0.10.0, LXC 0.8.0
* Container persistence via disk automount on `/var/lib/docker`
* SSH keys persistence via disk automount

## Installation

### Installation using the boot2docker manage script

#### OSX
```
$ brew update
$ brew install boot2docker
```

#### Linux/Unix (works also on OSX)
```
$ curl https://raw.github.com/boot2docker/boot2docker/master/boot2docker > boot2docker
$ chmod +x boot2docker
```

### Installing by hand

You can also use the boot2docker.iso and make your own virtual machine, or install on physical hardware.

Please remember to give the VM/hardware at least 512MB RAM - and you will need more if you want to do docker development on boot2docker.

## How to use
boot2docker comes with an init script that leverages VirtualBox's `VBoxManage`. You can start, stop and delete the VM right from the command line.

#### Initialize
```
$ boot2docker init
```

#### Start vm
```
$ boot2docker up
```


## Advanced usage

#### Port forwarding / folder sharing
In order to use this features refer to [this workarounds](https://github.com/boot2docker/boot2docker/blob/master/doc/WORKAROUNDS.md)

#### Customize
You can customise the values of `VM_NAME`, `DOCKER_PORT`, `SSH_HOST_PORT`, `VM_DISK`, `VM_DISK_SIZE`, `VM_MEM` and `BOOT2DOCKER_ISO` by setting them in `$HOME/.boot2docker/profile`

#### Persist data
When you run `boot2docker init`, the boot2docker manage script auto-creates
a disk that will be automounted and used to persist your docker data in
`/var/lib/docker` and `/var/lib/boot2docker`.
This virtual disk will be removed when you run `boot2docker delete`.
It will also persist the SSH keys of the machine.

If you are not using the boot2docker VirtualBox manage script, you can create
an ext4 formatted partition with the label `boot2docker-data`
(`mkfs.ext4 -L boot2docker-data /dev/sdX5`) to your VM or host, and
boot2docker will automount it on `/mnt/sdX` and then softlink
`/mnt/sdX/var/lib/docker` to `/var/lib/docker`.

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
use `dd if=boot2docker.iso of=/dev/sdX`.
This will create the small boot partition, and install an MBR.


#### Build your own boot2docker.iso
Goto [How to build](doc/BUILD.md) for Documentation on how to build your own boot2docker ISO's.
