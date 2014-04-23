Workarounds
===========

*Note: The following steps are meant as a temporary solution and won't be needed anymore in the future.*

## Port forwarding

Let's say your docker container exposes the port 8000 and you want access it from your host machine. Just run following command (and keep it open):

```sh
$ boot2docker ssh -L 8000:localhost:8000
```
## Port forwarding on steroid

If you use a lot of containers which expose the same port, you have to use docker dynamic port forwarding.
So for example running 3 **nginx** conatiners:

 - container-1 : 80 -> 49153
 - container-2 : 80 -> 49154
 - container-3 : 80 -> 49155

If you forward all 49XXX ports to your host. You can easily access all 3 webservers in you browser, without
any ssh localforwarding hack

``` sh
# vm must be powered off
for i in {49000..49900}; do
 VBoxManage modifyvm "boot2docker-vm" --natpf1 "tcp-port$i,tcp,,$i,,$i";
 VBoxManage modifyvm "boot2docker-vm" --natpf1 "udp-port$i,udp,,$i,,$i";
done
```

Now you can access your container from your host machine under `localhost:8000`


## Folder sharing

See https://github.com/boot2docker/boot2docker/pull/284 for an experimental build with VirtualBox shared folders support.

## BTRFS (ie, mkfs inside a privileged container)

Note: AUFS on top of BTRFS has many, many issues, so the boot2docker init script
will autodetect that `/var/lib/docker` is a btrfs partition and will set `-s btrfs`
for you.

```console
docker@boot2docker:~$ docker pull debian:latest
Pulling repository debian
...
docker@boot2docker:~$ docker run -i -t --rm --privileged -v /dev:/hostdev debian bash
root@5c3507fcae63:/# fdisk /hostdev/sda # if you need to partition your disk
Command: o
Command: n
Select: p
Partition: <enter>
First sector: <enter>
Last sector: <enter>
Command: w
root@5c3507fcae63:/# apt-get update && apt-get install btrfs-tools
...
The following NEW package will be installed:
  btrfs-tools
...
Setting up btrfs-tools (...) ...
root@5c3507fcae63:/# mkfs.btrfs -L boot2docker-data /hostdev/sda1
...
fs created label boot2docker-data on /hostdev/sda1
...
root@5c3507fcae63:/# exit
docker@boot2docker:~$ sudo reboot
```
