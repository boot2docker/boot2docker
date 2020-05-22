# DEPRECATED

Boot2Docker is officially deprecated and unmaintained.  It is recommended that users transition from Boot2Docker over to [Docker Desktop](https://www.docker.com/products/docker-desktop) instead (especially with [the new WSL2 backend, which supports Windows 10 Home](https://www.docker.com/blog/docker-desktop-for-windows-home-is-here/)).

These days there are a *lot* of tools designed to help spin up environments, and it's relatively easy to get something up and running with Docker installed with minimal effort.

# Boot2Docker

[![Build Status](https://travis-ci.org/boot2docker/boot2docker.svg?branch=master)](https://travis-ci.org/boot2docker/boot2docker)

Boot2Docker is a lightweight Linux distribution made specifically to run
[Docker](https://www.docker.com/) containers. It runs completely from RAM, is a
~45MB download and boots quickly.

## Features

* Recent Linux Kernel, Docker pre-installed and ready-to-use
* VM guest additions (VirtualBox, Parallels, VMware, XenServer)
* Container persistence via disk automount on `/var/lib/docker`
* SSH keys persistence via disk automount

> **Note:** Boot2Docker uses port **2376**, the [registered IANA Docker TLS
> port](http://www.iana.org/assignments/service-names-port-numbers/service-names-port-numbers.xhtml?search=docker)

## Caveat Emptor

Boot2Docker is designed and tuned for development.
**Using it for any kind of production workloads is highly discouraged.**

## Installation

Installation should be performed via [Docker Toolbox](https://docs.docker.com/toolbox/)
which installs [Docker Machine](https://docs.docker.com/machine/overview/), 
the Boot2Docker VM, and other necessary tools.

The [ISO can be downloaded
here](https://github.com/boot2docker/boot2docker/releases).

## How to use

Boot2Docker is used via [Docker Machine](https://docs.docker.com/machine/overview/) 
(installed as part of Docker Toolbox) which leverages VirtualBox's `VBoxManage` to
initialise, start, stop and delete the VM right from the command line.

## More information

See [Frequently asked questions](FAQ.md) for more details.

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
restarting the VM.

If you are not using the Docker Machine management tool, you can create an `ext4`
formatted partition with the label `boot2docker-data` (`mkfs.ext4 -L
boot2docker-data /dev/sdX5`) to your VM or host, and Boot2Docker will automount
it on `/mnt/sdX` and then softlink `/mnt/sdX/var/lib/docker` to
`/var/lib/docker`.
