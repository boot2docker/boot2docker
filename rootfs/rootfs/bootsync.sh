#!/bin/sh
. /etc/init.d/tc-functions

echo "${YELLOW}Running boot2docker init script...${NORMAL}"

# This log is started before the persistence partition is mounted
/opt/bootscript.sh 2>&1 | tee -a /boot.log
