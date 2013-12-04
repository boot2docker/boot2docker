#!/bin/sh
# Automount a hard drive
/etc/rc.d/automount

# Load TCE extensions
/etc/rc.d/tce-loader

# Configure SSHD
/etc/rc.d/sshd

# Launch Docker
/etc/rc.d/docker
