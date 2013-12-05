#!/bin/sh

/usr/bin/sethostname boot2docker

if grep -q '^docker:' /etc/passwd; then
  # if we have the docker user, let's create the docker group
  /bin/addgroup -S docker
  # ... and add our docker user to it!
  /bin/addgroup docker docker
fi

/opt/bootlocal.sh &
