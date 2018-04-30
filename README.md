# Boot2Docker

Boot2Docker is a lightweight Linux distribution made specifically to run
[Docker](https://www.docker.com/) containers. It runs completely from RAM, is a
~45MB download and boots quickly.

## Important Note

Boot2Docker is officialy in **maintenance mode** -- it is recommended that users transition from Boot2Docker over to [Docker for Mac](https://www.docker.com/docker-mac) or [Docker for Windows](https://www.docker.com/docker-windows) instead.

## Features

* Kernel 4.9.93 (with AUFS), Docker v18.05.0-ce-rc1
* VM guest additions (VirtualBox, Parallels, VMware, XenServer)
* Container persistence via disk automount on `/var/lib/docker`
* SSH keys persistence via disk automount

> **Note:** Boot2Docker uses port **2376**, the [registered IANA Docker TLS
> port](http://www.iana.org/assignments/service-names-port-numbers/service-names-port-numbers.xhtml?search=docker)

## Caveat Emptor

Boot2Docker is currently designed and tuned for development.  **Using it for
any kind of production workloads at this time is highly discouraged.**

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

### Migrate from `boot2docker` to Docker Machine

If you were using the `boot2docker` management tool previously, you have a 
pre-existing Docker `boot2docker-vm` VM on your local system. 
To allow Docker Machine to manage this older VM, you must migrate it,
see [Docker Machine documentation for details](https://docs.docker.com/machine/migrate-to-machine/).

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
formatted partition with the label `boot2docker-data` (`mkfs.ext4 -L
boot2docker-data /dev/sdX5`) to your VM or host, and Boot2Docker will automount
it on `/mnt/sdX` and then softlink `/mnt/sdX/var/lib/docker` to
`/var/lib/docker`.

#### Running behind HTTP(s) proxy

Running Docker in the environment with HTTP(S) proxy, which is still common in the corporate networks,
is hard because you have to provide the proxy address and authentication in multiple places.

Internet access is needed for example for:

* pulling images from Docker Hub
* downloading packages while building Docker images
* containers communication to the Internet

Setting `http_proxy` and `https_proxy` environment variables is usually not sufficient - not all programs support it.
To address this problem Boot2docker is capable of redirecting HTTP and HTTPS traffic to the proxy transparently,
but it requires some additional Docker Machine setup.

In the nutshell, either provide HTTP(S) proxy url via `--engine-env TRANSPARENT_HTTP_PROXY=user:password@proxy-host.com`
when creating a new Docker Machine or in `~/.docker/machine/machines/{machineName}/config.json` for existing machines.

This solution uses `iptables` and [redsocks](https://github.com/darkk/redsocks) to redirect tcp traffic
to [cntlm](http://cntlm.sourceforge.net).

The table below lists available configuration options.

| Environmental variable | Description |
| ---------------------- | ----------- |
| TRANSPARENT_HTTP_PROXY | The proxy host and optional user credentials e.g. `user:password@proxy-host.com`. When the proxy doesn't require authentication `user:password@` can be omitted. Remember that special characters in the user and password must be URL encoded. |
| TRANSPARENT_HTTP_PROXY_DOMAIN | `NTLM` domain used by `cntlm` together with user credentials |
| TRANSPARENT_NO_PROXY | Comma separated list of non-proxied host addresses. For example: `localhost,127.0.0.*,10.*, 192.168.*,*.domain.com` |
| TRANSPARENT_HTTP_PROXY_PORTS | Comma separate list of TCP ports mapping. Port can be either an exact value (e.g. 80) or ports range (e.g. 8080:8089), both ends inclusive. By default, traffic from ports 80 and 443 is proxied. For example: `80,443,8080:8089` |

Proxy can be easily disabled (e.g. when you are connected to open network at home) by removing `TRANSPARENT_HTTP_PROXY` variable from `~/.docker/machine/machines/{machineName}/config.json` file.

Each configuration change requires `docker-machine provision {machineName}` to be invoked.

Because it is quite common to have `cntlm` installed on the host machine, it can be reused by setting
`TRANSPARENT_HTTP_PROXY=10.0.2.2:3128` (`10.0.2.2` host machine ip address when accessed from Docker Machine, `3128`
default `cntlm` port). Similarly, when there is a HTTP(S) proxy on the network which doesn't require authentication,
set `TRANSPARENT_HTTP_PROXY=<proxy-address:port>`.

## Troubleshooting

See the [workarounds doc](https://github.com/boot2docker/boot2docker/blob/master/doc/WORKAROUNDS.md) for solutions to known issues.
