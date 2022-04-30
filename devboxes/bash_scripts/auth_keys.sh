#!/bin/sh

set -e

PAM_USER=${0}



homedir=$(/usr/bin/getent passwd "${PAM_USER}" | cut -d: -f6 ) > /dev/null 2>&1
getent _exit="${?}"

if [ "${getent _exit}" -eq 0 ] ; then
    # User actually exist.  Continue
    
    efshomedir="/efs$homedir"
    /usr/bin/cat "$efshomedir/.ssh/id_ed25519.pub" 
    cat _exit="${?}"
    if [ "${cat _exit}" -eq 0 ] ; then
        # User ssh key exist. exit nicely
        exit 0
    fi

fi


./opt/aws/bin/eic_run_authorized_keys "$@"