FAQ
====

**What are the specs of the VM?**

* CPU Cores: same as host (physical, not logical)
* 40gb HDD (auto-initialized at first boot)
* 1gb memory
* Autoboots to Boot2Docker
* `virtio` high performance networking
* NAT networked (Docker `2375->2375` and SSH `22->2022` are forwarded to the host)

**How can I solve my problems with SSH?**

If `ssh` complains about the keys:

```
$ ssh-keygen -R '[localhost]:2022'
```

**Login as root**

Run `sudo -s` as the docker user.

**What is the Boot2Docker distribution based on?**

It is based on a stripped down [Tiny Core Linux](http://tinycorelinux.net).

**Why not CoreOS?**

I got asked that question a lot, so I thought I should put it here once and for
all. [CoreOS](http://coreos.com/) is targeted at building infrastructure and
distributed systems. I just wanted the fastest way to boot to Docker.

**Persistent partition choice**

Boot2Docker will first try to mount a partition labeled ``boot2docker-data``, if
that doesn't exist, it will pick the first ``ext4`` partition listed by ``blkid``.

**Local Customisation (with persistent partition)**

If you have a persistence partition, you can make customisations that are run at
the end of the boot initialisation in the ``/var/lib/boot2docker/bootlocal.sh`` file.

You can also set variables that will be used during the boot initialisation (after
the automount) by setting them in `/var/lib/boot2docker/profile`

For example, to download ``pipework``, install its pre-requisites (which you can
download using ``tce-load -w package.tcz``), and then start a container:

```
#!/bin/sh


if [ ! -e /var/lib/boot2docker/pipework ]; then
        curl -o /var/lib/boot2docker/pipework https://raw.github.com/jpetazzo/pipework/master/pipework
        chmod 777 /var/lib/boot2docker/pipework
fi

#need ftp://ftp.nl.netbsd.org/vol/2/metalab/distributions/tinycorelinux/4.x/x86/tcz/bridge-utils.tcz
#and iproute2 (and its friends)
su - docker -c "tce-load -i /var/lib/boot2docker/*.tcz"

#start my management container if its not already there
docker run -d -v /var/run/docker.sock:/var/run/docker.sock $(which docker):$(which docker)  -name dom0 svens-dom0
```

Or, if you need to tell the Docker daemon to use a specific DNS server, add the 
following to ``/var/lib/boot2docker/profile``:

```
EXTRA_ARGS="--dns 192.168.1.2"
```

Another example: if you want to configure the Docker daemon to make profit of a registry mirror (docker >= 1.3.0), add the following to ``/var/lib/boot2docker/profile``:

```
DOCKER_REG_MIRROR=http://<private_registry_host>:<private_registry_port>
# ex: http://localhost:5000
# http or https depending on your registry setup
```
Please visit [Run a registry mirror](https://github.com/docker/docker/blob/master/docs/sources/articles/registry_mirror.md) for more information on how-to setup to activate this feature.

**What is the development process**

We are implementing the same process as [Docker merge approval](
https://github.com/dotcloud/docker/blob/master/CONTRIBUTING.md#merge-approval),
so all commits need to be done via pull requests, and will need 2 or more LGTMs.

**Is boot2docker only for VirtualBox?**

There are two parts of Boot2Docker: the ISO image, and the `boot2docker` management
tool to set up and mange a VM. The management tool only works with VirtualBox,
but the ISO image is designed to also be used with physical hardware. There
are no plans to make separate ISO images for different configurations.
