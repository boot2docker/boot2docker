Workarounds
===========

*Note: The following steps are meant as a temporary solution and won't be needed anymore in the future.*

## Port forwarding

Let's say your docker container exposes the port 8000 and you want access it from your host machine. Just run following command (and keep it open):

```sh
$ boot2docker ssh -L 8000:localhost:8000
```

Now you can access your container from your host machine under `localhost:8000`


## Folder sharing

If you want to access a folder on your host system from inside your docker container you neeed to have `sshfs` installed. (On OSX you can simply install it by `$ brew install sshfs`.)

Then log into your boot2docker VM (password is `tcuser`) with `$ boot2docker ssh` and run the following commands:

```sh
$ sudo mkdir /mnt/sda1/myapp
$ sudo chown -R docker:docker /mnt/sda1/myapp
```

Now you can logout again (by running `$ exit`) and create a file name `b2d-passwd` with the boot2docker password in it.

```sh
$ touch ~/.boot2docker/b2d-passwd
$ echo "tcuser" >> ~/.boot2docker/b2d-passwd
```

As a last step we have to mount the folder. Lets say you want to mount the folder `~/myapp` then simply run:

```sh
$ sshfs docker@localhost:/mnt/sda1/myapp ~/myapp -oping_diskarb,volname=b2d-myapp -p 2022 -o reconnect -o UserKnownHostsFile=/dev/null -o password_stdin < ~/.boot2docker/b2d-passwd
```

You can later unmount the folder with `$ umount -f  ~/myapp`.

You can now use the shared directory with docker like that:

```sh
$ docker run -v /mnt/sda1/myapp:/var/www 80e721db2a7b
```

## BTRFS (ie, mkfs inside a privileged container)

Note: AUFS on top of BTRFS has many, many issues.  If you do this, please don't
forget to change your docker graph backend using the `-s btrfs` daemon flag.

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
