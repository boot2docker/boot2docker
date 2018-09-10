# boot2docker

This directory contains a newly revamped `Dockerfile` for building `boot2docker.iso` which takes more direct advantage of TCL, especially `tce-load` for installing packages and their dependencies.

The intention is to release concurrent ISOs for several Docker releases, at which point this will become the sole provider of `boot2docker.iso` builds.
