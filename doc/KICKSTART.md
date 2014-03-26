#Kickstarting boot2docker using automated_script

#### Note! This guide assumes you have basic knowledge of how pxe booting works.

Kickstarting can be done by giving boot2docker an arbitrary script to download and execute. Boot2docker has a user being logged in automatically. This user has a .bashrc that points to a global bashrc and we will be append a full path to script that reads /proc/cmdline. It uses the built-in curl to download the script and execute it. To achieve this you will give boot2docker a uri as a boot parameter in this format; `SCRIPT=http://path.to/script.sh`. Currently boot2docker has a timeout of 0 which means we will never be able to set this parameter upon boot. Instead we will use iPXE to set the parameter.


The file being served from the dhcp server `undionly.kpxe` has an embedded script that tells it what to do next. [http://ipxe.org/embed#embedding_within_the_ipxe_binary](http://ipxe.org/embed#embedding_within_the_ipxe_binary)
Booting from the following embedded script will try to chainload a script custom to its mac address. It will first try https and if it does not succeed; http.

```
#!ipxe
dhcp

chain https://192.168.3.3/execute/${mac:hexhyp} ||
goto http

:http
chain http://192.168.3.3:4321/execute/${mac:hexhyp} ||
goto solve

:solve
prompt --key 0x02 --timeout 2000 Press Ctrl-B for the iPXE command line... && shell ||
exit 0
```

Lets say that it will chainload to the following script. The append variable is what shows up on /proc/cmdline. The vmlinuz64 and initrd.img is what is beeing booted from the network. You will need to extract these from the boot2docker iso and place it somewhere iPXE can reach it. 

```
#!ipxe

set script http://path.to/script.sh
set append loglevel=3 user=docker console=ttyS0 console=tty nomodeset norestore base script=${script}
set kernel http://boot.home.local/agent/vmlinuz64
set initrd http://boot.home.local/agent/initrd.img


imgfree
kernel ${kernel} ${append}
initrd ${initrd}
boot
```

Simplest example of a script beeing executed from the script parameter.

```
#!/bin/bash
docker run -d pandrew/rethinkdb
```
