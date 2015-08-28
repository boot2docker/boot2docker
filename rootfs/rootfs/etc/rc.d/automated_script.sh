#!/bin/sh

script_cmdline ()
{
    local param
    for param in $(cat /proc/cmdline); do
        case "${param}" in
            script=*) echo "${param##*=}" ; return 0 ;;
        esac
    done
}

automated_script ()
{
    local script rt
    script="$(script_cmdline)"
    if [[ -n "${script}" && ! -x /tmp/startup_script ]]; then
        if [[ "${script%%//*}" == "http:" || "${script%%//*}" == "ftp:" ]]; then
            curl -fsL "${script}" -o /tmp/startup_script
            rt=$?
        else
            cp "${script}" /tmp/startup_script
            rt=$?
        fi
        if [[ ${rt} -eq 0 ]]; then
            chmod +x /tmp/startup_script
            /tmp/startup_script
        fi
    fi
}

automated_script
