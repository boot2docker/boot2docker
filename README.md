Boot2Docker
===========

Boot2Docker is a lightweight Linux distribution made specifically to run [Docker]
(https://www.docker.io/) containers. It runs completely from RAM, is a small ~24MB
download and boots in ~5s (YMMV).


Installation instructions for [OS X](http://docs.docker.io/installation/mac/) and [Windows](http://docs.docker.io/installation/windows/) available on the Docker documentation site.


The [ISO can be downloaded here](
https://github.com/boot2docker/boot2docker/releases).


## Features
* Kernel 3.16.1 with AUFS, Docker v1.2.0 - using libcontainer
* Container persistence via disk automount on `/var/lib/docker`
* SSH keys persistence via disk automount

> **Note:** This version of Docker uses port **2375**, the newly registered [IANA
> port](http://www.iana.org/assignments/service-names-port-numbers/service-names-port-numbers.xhtml?search=docker)

## Installation

### All in one Installers for OS X and MS Windows

We have built installers for [OS X](
https://github.com/boot2docker/osx-installer/releases) and [MS Windows](
https://github.com/boot2docker/windows-installer/releases) which will install
the boot2docker management tool, VirtualBox and any tools needed to run Boot2Docker.

### Installation using the boot2docker management tool

If you have the prerequisites, or want to help develop Boot2Docker, you can 
also download the appropriate [boot2docker management release](
https://github.com/boot2docker/boot2docker-cli/releases) and use it to download
the [`boot2docker.iso`](
https://github.com/boot2docker/boot2docker/releases).

## How to use
The `boot2docker` management tool leverages VirtualBox's `VBoxManage` to
initialise, start, stop and delete the VM right from the command line.

#### Initialize
```
$ boot2docker init
```

#### Start VM
```
$ boot2docker up
```

#### Upgrade the Boot2docker VM image
```
$ boot2docker stop
$ boot2docker download
$ boot2docker up
```

If your Boot2Docker virtual machine was created prior to 0.11.1-pre1, it's best to
delete -  `boot2docker delete` and then `boot2docker init` to create a new VM.

The main changes are to add a `/var/lib/boot2docker/userdata.tar` file that is
un-tarred into the `/home/docker` directory on boot. This file contains a
`.ssh/authorized_keys` and `.ssh/authorized_keys2` files containing a public sshkey.


## More information

See [Frequently asked questions](doc/FAQ.md) for more details.

#### Boot script log

The bootup script output is logged to `/boot.log`, so you can see (and potentially debug)
what happens. Note that this is not persistent between boots because we're logging
from before the persistence partition is mounted (and it may not exist at all).

#### Container Port redirection 

The latest version of `boot2docker` sets up two network adaptors, one using NAT
to allow the VM to download images and files from the internet, and a host only
network that Docker container's ports will be exposed on.

If you run a container with an exposed port:

```
   $ docker run --rm -i -t -p 80:80 apache
```

Then you should be able to access that apache server using the IP address reported
to you using:

```
   $ boot2docker ip
   192.168.59.103
```

Typically, it is 192.168.59.103, but it can change as its dynamically allocated
by the VirtualBox DHCP server.

If you want to share container ports with other computers on your LAN, you will
need to set up [NAT adaptor based port forwarding](
https://github.com/boot2docker/boot2docker/blob/master/doc/WORKAROUNDS.md)

#### Folder sharing

Boot2Docker is essentially a remote Docker engine with a read only filesystem
(other than Docker images, containers and volumes). The most scalable and portable
way to share disk space between your local desktop and a Docker container is by
creating a volume container and then sharing that to where it's needed.

One well tested approach is to use a file sharing container like `svendowideit/samba`

e.g:

```
    # Make a volume container (only need to do this once)
    $ docker run -v /data --name my-data busybox true
	# Share it using Samba (Windows file sharing)
	$ docker run --rm -v /usr/local/bin/docker:/docker -v /var/run/docker.sock:/docker.sock svendowideit/samba my-data
	# then find out the IP address of your Boot2Docker host
	$ boot2docker ip
	192.168.59.103
```
Connect to the shared folder using Finder (OS X):

	 Connect to cifs://192.168.59.103/data
	 Once mounted, will appear as /Volumes/data


Or on Windows, use Explorer to Connect to:

	\\192.168.59.103\data


You can then use your data container from any container you like:

```
	docker run -it --volumes-from my-data ubuntu 
```

You will find the "data" volume mounted as "/data" in that container. Note that "my-data" is the name of volume container, this is shared via the "network" by the "samba" container that refers to it by name. So, in this example, if you were on OS-X you now have /Volumes/data and /data in container being shared. You can change the paths as needed. 

#### Customize
The `boot2docker` management tool allows you to customise many options from both the
commandline, or by setting them in its configuration file.

see `boot2docker config` for more (including the format of the configuration file).


#### SSH into VM
```
$ boot2docker ssh
```
Boot2Docker auto logs in using the generated SSH key, but if you want to SSH into
the machine manually (or you're not using a `boot2docker` managed VM), the credentials are:
```
user: docker
pass: tcuser
```


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


#### Install on any device
To 'install' the ISO onto an SD card, USB-Stick or even empty hard disk, you can
use `dd if=boot2docker.iso of=/dev/sdX`.
This will create the small boot partition, and install an MBR.


#### Build your own boot2docker.iso
Goto [How to build](doc/BUILD.md) for Documentation on how to build your own boot2docker ISOs.

## Troubleshooting

#### `boot2docker up` doesn't work (OSX)

Sometimes OSX will install updates that break VirtualBox and require a restart 
of the kernel extensions that boot2docker needs in order to run.  If you go to 
boot boot2docker after some updates or a system restart and you get an output 
such as the following:

```
$ boot2docker up
error in run: Failed to start machine "boot2docker-vm" (run again with -v for details)
```

You may need to reload the kernel extensions in order to get your system
functioning again.

In this case, try running the following script (supplied with Virtual Box):

```
$ sudo /Library/Application\ Support/VirtualBox/LaunchDaemons/VirtualBoxStartup.sh restart
```

You should see output such as:

```
/Applications/VirtualBox.app/Contents/MacOS/VBoxAutostart => /Applications/VirtualBox.app/Contents/MacOS/VBoxAutostart-amd64
/Applications/VirtualBox.app/Contents/MacOS/VBoxBalloonCtrl => /Applications/VirtualBox.app/Contents/MacOS/VBoxBalloonCtrl-amd64
/Applications/VirtualBox.app/Contents/MacOS/VBoxDD2GC.gc => /Applications/VirtualBox.app/Contents/MacOS/VBoxDD2GC.gc-amd64
/Applications/VirtualBox.app/Contents/MacOS/VBoxDDGC.gc => /Applications/VirtualBox.app/Contents/MacOS/VBoxDDGC.gc-amd64
/Applications/VirtualBox.app/Contents/MacOS/VBoxExtPackHelperApp => /Applications/VirtualBox.app/Contents/MacOS/VBoxExtPackHelperApp-amd64
/Applications/VirtualBox.app/Contents/MacOS/VBoxHeadless => /Applications/VirtualBox.app/Contents/MacOS/VBoxHeadless-amd64
/Applications/VirtualBox.app/Contents/MacOS/VBoxManage => /Applications/VirtualBox.app/Contents/MacOS/VBoxManage-amd64
/Applications/VirtualBox.app/Contents/MacOS/VBoxNetAdpCtl => /Applications/VirtualBox.app/Contents/MacOS/VBoxNetAdpCtl-amd64
/Applications/VirtualBox.app/Contents/MacOS/VBoxNetDHCP => /Applications/VirtualBox.app/Contents/MacOS/VBoxNetDHCP-amd64
/Applications/VirtualBox.app/Contents/MacOS/VBoxNetNAT => /Applications/VirtualBox.app/Contents/MacOS/VBoxNetNAT-amd64
/Applications/VirtualBox.app/Contents/MacOS/VBoxSVC => /Applications/VirtualBox.app/Contents/MacOS/VBoxSVC-amd64
/Applications/VirtualBox.app/Contents/MacOS/VBoxXPCOMIPCD => /Applications/VirtualBox.app/Contents/MacOS/VBoxXPCOMIPCD-amd64
/Applications/VirtualBox.app/Contents/MacOS/VMMGC.gc => /Applications/VirtualBox.app/Contents/MacOS/VMMGC.gc-amd64
/Applications/VirtualBox.app/Contents/MacOS/VirtualBox => /Applications/VirtualBox.app/Contents/MacOS/VirtualBox-amd64
/Applications/VirtualBox.app/Contents/MacOS/VirtualBoxVM => /Applications/VirtualBox.app/Contents/MacOS/VirtualBoxVM-amd64
/Applications/VirtualBox.app/Contents/MacOS/vboxwebsrv => /Applications/VirtualBox.app/Contents/MacOS/vboxwebsrv-amd64
Loading VBoxDrv.kext
Loading VBoxUSB.kext
Loading VBoxNetFlt.kext
Loading VBoxNetAdp.kext
```

Now the VM should boot properly.
