Boot2Docker
===========

Boot2Docker is a lightweight Linux distribution made specifically to run [Docker](https://www.docker.io/) containers. It runs completely from RAM, weighs ~24MB and boots in ~5s (YMMV). The [ISO can be download here](https://github.com/boot2docker/boot2docker/releases).

[![Boot2Docker Demo Video](http://i.imgur.com/hIwudK3.gif)](http://www.youtube.com/watch?v=QzfddDvNVv0&hd=1)

See [Frequently asked questions](doc/FAQ.md) for more details.

## Features
* Kernel 3.14.1 with AUFS, Docker 0.11.1 - using libcontainer
* Container persistence via disk automount on `/var/lib/docker`
* SSH keys persistence via disk automount

## Installation

### All in one Installers for OS X and MS Mindows

We have built installers for [OS X](
https://github.com/boot2docker/osx-installer/releases) and [MS Windows](
https://github.com/boot2docker/windows-installer/releases) which will install
the `boot2docker` management tool, VirtualBox and any tools needed to run Boot2Docker.

### Installation using the `boot2docker` manage tool

If you have the pre-requisites, or want to help develop Boot2Docker, you can 
also download the appropriate [boot2docker management release](
https://github.com/boot2docker/boot2docker-cli/releases) and use it to download
the [`boot2docker.iso`](
https://github.com/boot2docker/boot2docker/releases).

## How to use
The `boot2docker` managment tool leverages VirtualBox's `VBoxManage` to
initialise, start, stop and delete the VM right from the command line.

#### Initialize
```
$ boot2docker init
```
or [via Puppet](https://github.com/shaftoe/puppet-boot2docker)

#### Start vm
```
$ boot2docker up
```

#### Upgrade the Boot2docker vm image
```
$ boot2docker stop
$ boot2docker download
$ boot2docker up
```


## More information

#### Container Port redirection 

The latest version of `boot2docker` sets up two network adaptors, one using NAT
to allow the VM to download images and files from the Internet, and a host only
network that Docker container's ports will be exposed on.

If you run a container with an exposed port:

```
   docker run --rm -i -t -p 80:80 apache
```

Then you should be able to access that apache server using the IP address reported
to you using:

```
   boot2docker ssh ip addr show dev eth1
```

Typically, it is 192.168.59.103, but at this point it can change.

If you want to share container ports with other computers on your LAN, you will
need to set up [NAT adaptor based port forwarding](
https://github.com/boot2docker/boot2docker/blob/master/doc/WORKAROUNDS.md)

#### folder sharing

TODO: Volume container sharing using a Samba container.

#### Customize
The `boot2docker` manage tool allows you to customise many options from both the
commandline, or by setting them in its configuration file.

see `boot2docker config` for more.


#### Persist data
When you run `boot2docker init`, the `boot2docker` tool auto-creates
a disk that will be automounted and used to persist your docker data in
`/var/lib/docker` and `/var/lib/boot2docker`.
This virtual disk will be removed when you run `boot2docker delete`.
It will also persist the SSH keys of the machine.

If you are not using the `boot2docker` VirtualBox manage tool, you can create
an `ext4` or `btrfs` formatted partition with the label `boot2docker-data`
(`mkfs.ext4 -L boot2docker-data /dev/sdX5`) to your VM or host, and
boot2docker will automount it on `/mnt/sdX` and then softlink
`/mnt/sdX/var/lib/docker` to `/var/lib/docker`.

#### SSH into VM
```
$ boot2docker ssh
```
`boot2docker` auto logs in using the generated ssh key, but if you want to SSH into the machine, the credentials are:
```
user: docker
pass: tcuser
```


#### Install on any device
To 'install' the ISO onto an SD card, USB-Stick or even empty hard disk, you can
use `dd if=boot2docker.iso of=/dev/sdX`.
This will create the small boot partition, and install an MBR.


#### Build your own boot2docker.iso
Goto [How to build](doc/BUILD.md) for Documentation on how to build your own boot2docker ISOs.
