#!/bin/sh
set -ex
PROJECT_ID=${PROJECT_ID:-fleet-parsec-418}
BUCKET=${BUCKET:-${PROJECT_ID}}
IMAGE=$(readlink -f ${1:-disk.img})
NAME=boot2docker-$(date +%s)
TMPDIR=$(mktemp -d)
pushd $TMPDIR
function defer {
  popd
}
trap defer EXIT

cp $IMAGE disk.raw
tar -Szcf $NAME.tar.gz disk.raw
gsutil cp $NAME.tar.gz gs://$BUCKET/
gcutil addimage $NAME gs://$BUCKET/$NAME.tar.gz
gcutil addinstance vm-$NAME-test --image=$NAME --zone=us-central1-a --machine_type=machineTypes/f1-micro
gcutil getserialportoutput vm-$NAME-test
