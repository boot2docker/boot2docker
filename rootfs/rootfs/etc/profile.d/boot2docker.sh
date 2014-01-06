#!/bin/sh

echo "boot2docker: $(cat /etc/version)"
echo "docker: $(docker version)"
echo "lxc: $(lxc-version)"
