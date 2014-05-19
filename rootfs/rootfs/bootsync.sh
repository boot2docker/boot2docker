#!/bin/sh
. /etc/init.d/tc-functions

echo "${YELLOW}Running boot2docker init script...${NORMAL}"

nohup /opt/bootscript.sh >> /boot.log &

