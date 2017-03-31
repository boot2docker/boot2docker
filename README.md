# Boot2Docker

Boot2Docker is a lightweight Linux distribution made specifically to run
[Docker](https://www.docker.com/) containers. It runs completely from RAM, is a
small ~38MB download and boots in ~5s (YMMV).

## Features

* Kernel 4.4.59 with AUFS, Docker v17.03.0-ce - using libcontainer
* Container persistence via disk automount on `/var/lib/docker`
* SSH keys persistence via disk automount

> **Note:** Boot2Docker uses port **2376**, the [registered IANA Docker TLS
> port](http://www.iana.org/assignments/service-names-port-numbers/service-names-port-numbers.xhtml?search=docker)

## Caveat Emptor

Boot2Docker is currently designed and tuned for development.  Using it for
any kind of production workloads at this time is highly discouraged.

## Installation

Installation should be performed via [Docker Toolbox](https://www.docker.com/products/docker-toolbox)
which installs [Docker Machine](https://docs.docker.com/machine/overview/), 
the Boot2Docker VM, and other necessary tools.

The [ISO can be downloaded
here](https://github.com/boot2docker/boot2docker/releases).

## How to use

Boot2Docker is used via [Docker Machine](https://docs.docker.com/machine/overview/) 
(installed as part of Docker Toolbox) which leverages VirtualBox's `VBoxManage` to
initialise, start, stop and delete the VM right from the command line.

### Migrate from `boot2docker` to Docker Machine

If you were using the `boot2docker` management tool previously, you have a 
pre-existing Docker `boot2docker-vm` VM on your local system. 
To allow Docker Machine to manage this older VM, you must migrate it,
see [Docker Machine documentation for details](https://docs.docker.com/machine/migrate-to-machine/).

## Docker Hub

To save and share container images, automate workflows, and more sign-up for a
free [Docker Hub account](https://hub.docker.com).

## More information

See [Frequently asked questions](doc/FAQ.md) for more details.

#### Boot script log

The bootup script output is logged to `/boot.log`, so you can see (and
potentially debug) what happens. Note that this is not persistent between boots
because we're logging from before the persistence partition is mounted (and it
may not exist at all).

#### Docker daemon options

If you need to customize the options used to start the Docker daemon, you can
do so by adding entries to the `/var/lib/boot2docker/profile` file on the
persistent partition inside the Boot2Docker virtual machine. Then restart the
daemon.

The following example will enable core dumps inside containers, but you can
specify any other options you may need.

```console
docker-machine ssh default -t sudo vi /var/lib/boot2docker/profile
# Add something like:
#     EXTRA_ARGS="--default-ulimit core=-1"
docker-machine restart default
```

#### Folder sharing

Boot2Docker is essentially a remote Docker engine with a read only filesystem
(other than Docker images, containers and volumes). The most scalable and
portable way to share disk space between your local desktop and a Docker
container is by creating a volume container and then sharing that to where it's
needed.

One well tested approach is to use a file sharing container like
`svendowideit/samba`:

```console
$ # Make a volume container (only need to do this once)
$ docker run -v /data --name my-data busybox true
$ # Share it using Samba (Windows file sharing)
$ docker run --rm -v /usr/local/bin/docker:/docker -v /var/run/docker.sock:/docker.sock svendowideit/samba my-data
$ # then find out the IP address of your Boot2Docker host
$ docker-machine ip default
192.168.59.103
```

Connect to the shared folder using Finder (OS X):

	Connect to cifs://192.168.59.103/data
	Once mounted, will appear as /Volumes/data

Or on Windows, use Explorer to Connect to:

	\\192.168.59.103\data

You can then use your data container from any container you like:

```console
$ docker run -it --volumes-from my-data ubuntu
```

You will find the "data" volume mounted as "/data" in that container. Note that
"my-data" is the name of volume container, this is shared via the "network" by
the "samba" container that refers to it by name. So, in this example, if you
were on OS-X you now have /Volumes/data and /data in container being shared. You
can change the paths as needed.

##### VirtualBox Guest Additions

Alternatively, Boot2Docker includes the VirtualBox Guest Additions built in for
the express purpose of using VirtualBox folder sharing.

The first of the following share names that exists (if any) will be
automatically mounted at the location specified:

1. `Users` share at `/Users`
2. `/Users` share at `/Users`
3. `c/Users` share at `/c/Users`
4. `/c/Users` share at `/c/Users`
5. `c:/Users` share at `/c/Users`

If some other path or share is desired, it can be mounted at run time by doing
something like:

```console
$ mount -t vboxsf -o uid=1000,gid=50 your-other-share-name /some/mount/location
```

It is also important to note that in the future, the plan is to have any share
which is created in VirtualBox with the "automount" flag turned on be mounted
during boot at the directory of the share name (ie, a share named `home/jsmith`
would be automounted at `/home/jsmith`).

In case it isn't already clear, the Linux host support here is currently hazy.
You can share your `/home` or `/home/jsmith` directory as `Users` or one of the
other supported automount locations listed above, but note that you will then
need to manually convert your `docker run -v /home/...:...` bind-mount host
paths accordingly (ie, `docker run -v /Users/...:...`).  As noted in the
previous paragraph however, this is likely to change in the future as soon as a
more suitable/scalable solution is found and implemented.


#### Installing secure Registry certificates

As discussed in the [Docker Engine documentation](https://docs.docker.com/engine/security/certificates/#/understanding-the-configuration)
certificates should be placed at `/etc/docker/certs.d/hostname/ca.crt` 
where `hostname` is your Registry server's hostname.

```console
docker-machine scp certfile default:ca.crt
docker-machine ssh default
sudo mv ~/ca.crt /etc/docker/certs.d/hostname/ca.crt
exit
docker-machine restart
```

Alternatively the older Boot2Docker method can be used and you can add your 
Registry server's public certificate (in `.pem` or `.crt` format) into
the `/var/lib/boot2docker/certs/` directory, and Boot2Docker will automatically
load it from the persistence partition at boot.

You may need to add several certificates (as separate `.pem` or `.crt` files) to this
directory, depending on the CA signing chain used for your certificate.

##### Insecure Registry

As of Docker version 1.3.1, if your registry doesn't support HTTPS, you must add it as an
insecure registry.

```console
$ docker-machine ssh default "echo $'EXTRA_ARGS=\"--insecure-registry <YOUR INSECURE HOST>\"' | sudo tee -a /var/lib/boot2docker/profile && sudo /etc/init.d/docker restart"
```

then you should be able to do a docker push/pull.

#### Running behind a VPN (Cisco AnyConnect, etc)

So sometimes if you are behind a VPN, you'll get an `i/o timeout` error.
The current work around is to forward the port in the boot2docker-vm.

If you get an error like the following:

```no-highlight
Sending build context to Docker daemon
2014/11/19 13:53:33 Post https://192.168.59.103:2376/v1.15/build?rm=1&t=your-tag: dial tcp 192.168.59.103:2376: i/o timeout
```

That means you have to forward port `2376`, which can be done like so:

* Open VirtualBox
* Open Settings > Network for your 'default' VM
* Select the adapter that is 'Attached To': 'NAT' and click 'Port Forwarding'.
* Add a new rule:
	- Protocol: TCP
	- Host IP: 127.0.0.1
	- Host Port: 5555
	- Guest Port: 2376
* Set `DOCKER_HOST` to 'tcp://127.0.0.1:5555'

#### SSH into VM

```console
$ docker-machine ssh default
```

Docker Machine auto logs in using the generated SSH key, but if you want to SSH
into the machine manually (or you're not using a Docker Machine managed VM), the
credentials are:

```
user: docker
pass: tcuser
```

#### Persist data

Boot2docker uses [Tiny Core Linux](http://tinycorelinux.net), which runs from
RAM and so does not persist filesystem changes by default.

When you run `docker-machine`, the tool auto-creates a disk that
will be automounted and used to persist your docker data in `/var/lib/docker`
and `/var/lib/boot2docker`.  This virtual disk will be removed when you run
`docker-machine delete default`.  It will also persist the SSH keys of the machine.
Changes outside of these directories will be lost after powering down or
restarting the VM - to make permanent modifications see the
[FAQ](doc/FAQ.md#local-customisation-with-persistent-partition).

If you are not using the Docker Machine management tool, you can create an `ext4`
or `btrfs` formatted partition with the label `boot2docker-data` (`mkfs.ext4 -L
boot2docker-data /dev/sdX5`) to your VM or host, and Boot2Docker will automount
it on `/mnt/sdX` and then softlink `/mnt/sdX/var/lib/docker` to
`/var/lib/docker`.

#### Install on any device

To 'install' the ISO onto an SD card, USB-Stick or even empty hard disk, you can
use `dd if=boot2docker.iso of=/dev/sdX`.  This will create the small boot
partition, and install an MBR.

#### Build your own Boot2Docker ISO

Goto [How to build](doc/BUILD.md) for Documentation on how to build your own
Boot2Docker ISOs.

## Troubleshooting

See the [workarounds doc](https://github.com/boot2docker/boot2docker/blob/master/doc/WORKAROUNDS.md) for solutions to known issues.
