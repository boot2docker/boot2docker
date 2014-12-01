#!/bin/bash
set -e

docker build -t temp .
docker run --rm temp cat /tmp/docker.iso > docker.iso
ls -lh docker.iso
