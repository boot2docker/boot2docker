#!/bin/sh

# Load TCE extensions
/etc/rc.d/tce-loader

# Automount a hard drive
/etc/rc.d/automount

# TODO: from here in, we could use /var/lib/boot2docker/etc/rc.d

# set the hostname
/etc/rc.d/hostname

# TODO: move this (and the docker user creation&pwd out to its own over-rideable?))
if grep -q '^docker:' /etc/passwd; then
    # if we have the docker user, let's create the docker group
    /bin/addgroup -S docker
    # ... and add our docker user to it!
    /bin/addgroup docker docker
fi

# Configure SSHD
/etc/rc.d/sshd

# Launch ACPId
/etc/rc.d/acpid

# Launch Docker
/etc/rc.d/docker

# Allow local HD customisation
if [ -e /var/lib/boot2docker/bootlocal.sh ]; then
    /var/lib/boot2docker/bootlocal.sh &
fi
