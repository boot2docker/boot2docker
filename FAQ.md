# FAQ

## I've just installed a new Boot2Docker and I get `client and server don't have the same version`

There's a good chance that your Boot2Docker virtual machine existed before you
upgraded your Docker client.

## How can I solve my problems with SSH?

If `ssh` complains about the keys:

```
$ ssh-keygen -R '[localhost]:2022'
```

## Login as root

Run `sudo -s` as the docker user.

## What is the Boot2Docker distribution based on?

It is based on a stripped down [Tiny Core Linux](http://tinycorelinux.net).

## Persistent partition choice

Boot2Docker will first try to mount a partition labeled `boot2docker-data`, if
that doesn't exist, it will pick the first `ext4` partition listed by `blkid`.

## Local Customisation (with persistent partition)

Changes outside of the `/var/lib/docker` and `/var/lib/boot2docker` directories
will be lost after powering down or restarting the boot2docker VM. However, if
you have a persistence partition (created automatically by `boot2docker init`),
you can make customisations that are run at the end of boot initialisation by
creating a script at `/var/lib/boot2docker/bootlocal.sh`.

From Boot2Docker version 1.6.0, you can also specify steps that are run before
the Docker daemon is started, using `/var/lib/boot2docker/bootsync.sh`.

You can also set variables that will be used during the boot initialisation (after
the automount) by setting them in `/var/lib/boot2docker/profile`

For example, to download `pipework`, install its pre-requisites (which you can
download using `tce-load -w package.tcz`), and then start a container:

```bash
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
following to `/var/lib/boot2docker/profile`:

```bash
EXTRA_ARGS="$EXTRA_ARGS --dns 192.168.1.2"
```
