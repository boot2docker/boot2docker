#!/bin/sh
script_cmdline ()
{
    params=$(cat /proc/cmdline)
    for param in $params; do
        case $param in 
	    script=*) echo "${param##*=}" ; return 0 ;;
        esac
    done
}

automated_script ()
{
    script="$(script_cmdline)"
    if [ -n "${script}" ]; then
    	curl -fsL "${script}" -o /startup_script
   	rt=$?
    	if [ $rt == 0 ]; then
    		chmod +x /startup_script
		echo "Run automated script ${script}" >> /var/log/boot2docker.log 
		/startup_script
    	fi
    fi
}

automated_script
