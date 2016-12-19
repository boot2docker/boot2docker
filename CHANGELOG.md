# Changelog

## 1.4.1 (2014-12-16)
- Docker v1.4.1

## 1.4.0 (2014-12-11)
- Docker v1.4.0

## 1.3.3 (2014-12-11)
- Docker v1.3.3
- run ntpd and restart it hourly to combat laptop sleep / VM suspend clock issues (#661, #662)

## 1.3.2 (2014-11-24)
- Docker v1.3.2
- Linux v3.16.7 (#642)
- Hyper-V support (#595)

## 1.3.1 (2014-10-30)
- Docker v1.3.1
- made it possible to disable TLS (#572)

## 1.3.0 (2014-10-16)
- Docker v1.3.0
- Linux v3.16.4 (#552)
- TLS certificate generation and use by default (#563)
- VirtualBox Guest Additions mounting (#534, #567)
- only /Users and /c/Users automatically for now
- see also https://github.com/boot2docker/boot2docker#virtualbox-guest-additions
- enabled BINFMT_MISC in the kernel (#523)
- enabled EXT4_FS_POSIX_ACL and EXT4_FS_SECURITY in the kernel (#543)
- shortened the ntpclient delay period and check interval (#554)

## 1.2.0 (2014-08-22)
- Docker v1.2.0
- Linux Kernel 3.16.1
- Add /etc/os-release file version and distro info.
- Attempt to sync the clock better
- Add /var/lib/boot2docker/profile for customising Docker daemon settings
- Speed up SSH by turning off DNS check
- Log boot output to /var/log/boot2docker.log
- Add infrastructure to allow Docker TLS Socket
- Fix devmapper Docker test
- Fix fix 'sudo -i and sudo su -'

## 1.1.2 (2014-07-23)
- Update to Docker v1.1.2
- enable swap if available

## 1.1.1 (2014-07-09)
- Update to Docker v1.1.1

## 1.1.0 (2014-07-03)
- Docker v1.1.0
- Linux Kernel 3.15.3
- increased the disk wait time to 10 seconds - Will need more debugging.

## 1.0.1 (2014-06-19)
- Docker v1.0.1 - [Change log](https://github.com/dotcloud/docker/blob/master/CHANGELOG.md)
- Wait for up to 3 seconds for the boot2docker-data partition to be ready

## 1.0.0 (2014-06-09)
- Docker v1.0.0
- use the official IANA registered Docker port
- add support for a serial console
- Note: this update changes the exposed Docker port from 4243 to 2375, and will require the v0.12.0 version of the new boot2docker management tool.
- This Boot2Docker release is not backwards compatible with older management tools

- Note: if you are upgrading, please create a new VM using boot2docker delete ; boot2docker download ; boot2docker up. This will delete your persistent data, but will also ensure that you have the latest VirtualBox configuration.

## 0.12.0 (2014-06-06)
- Docker v0.12.0
- use the official IANA registered Docker port
- add support for a serial console
- Note: this update changes the exposed Docker port from 4243 to 2375, and will require the v0.12.0 version of the new boot2docker management tool.
- This Boot2Docker release is not backwards compatible with older management tools

## 0.9.1 (2014-05-14)
- Docker 0.11.1, Linux kernel 3.14.1
- reduce the input lag / freezing issue by changing the Linux kernel timer (CONFIG_HZ=100)
- add logging to dhcp events

## 0.9.0 (2014-05-09)
- Docker v0.11.1
- fix for docker rm failure: #342
- remove lxc utils, bash and ncurses - focus on libcontainer use.
- faster simpler single Dockerfile build using a Docker.io trusted build - https://index.docker.io/u/boot2docker/boot2docker/

## 0.8.1 (2014-05-07)
- Update to Docker 0.11

## 0.8.0 (2014-04-08)
- Docker 0.10
- fix for VirtualBox Saved state

## 0.7.1 (2014-03-25)
- Docker 0.9.1
- Hyper-V kernel module support
- improve shutdown script triggering

## 0.7.0 (2014-03-12)
- Docker 0.9.0
- Use the kernel dhcp client
- Patch for Kernel panic on VirtualBox 4.3.8 on OSX
- Use Trusted builds to make releases.
- Added a 1GB swap partition to the auto-formated disk (you will need to do a ./boot2docker delete)

## 0.6.0 (2014-02-20)
- Docker 0.8.1
- BTRFS support
- DeviceMapper support
- Linux Kernel 3.13.3
- Enable IPv6 forwarding
- Added iproute2
- Fixed time and VM time drift in VM via ntpclient
- Removed wireless support
- Removed useless kernel modules
- b2d is 3mb slimmer (27mb -> 24mb)
- Various all around fixes

## 0.5.4 (2014-02-06)
- Resolve symlinked /tmp so 'docker build' won't fail

## 0.5.3 (2014-02-06)
- fix the docker rm bug
- add git (for docker build from git)
- add real xz (required by certain images)
- /tmp moved to disk
- removed pipework
- fix a bug where TCL could restore unwanted state
- detect if ports needed for ssh and docker are free on localhost

## 0.5.2 (2014-02-05)
- Docker 0.8

## 0.5.1 (2014-02-04)
- Fix an issue where dockerd would not listen on tcp://, causing the Mac client not to work

## 0.5.0 (2014-02-04)
- LXC 0.8.0 (fixes ghost issues)
- docker 0.7.6
- better/cleaner disk persistance
- can boot over an existing linux install and use its containers
- includes pipework by @jpetazzo
- lots of fixes
- script: init will perform auto disk partition/formatting
- script: ~/.boot2docker/profile customisation support
- script: no more ssh key errors

## 0.4.0 (2014-01-13)
- Automatically let dockerd listen on all interface if running in a VM (boot2docker)
- Upgrade to LXC 1.0 beta1
- Kernel now fully support cgroups
- Disable frame buffer on boot (useful for cloud)
- Fix some automount issues
- ACPI support

## 0.3.0 (2013-12-08)
- Docker v0.7.1
- 40% reduced size (38mb to 23mb)
- Hybrid ISO file (install by dd the ISO to a hard drive)
- Firmware files and iw tools for wifi cards

## 0.2 (2013-12-04)
- This version adds a nicer boot process, no longer requires sudo, and properly redirects the console to ttyS0.

## 0.1 (2013-12-03)
- This is the first version of boot2docker. Just download this ISO and boot from it to get started.
