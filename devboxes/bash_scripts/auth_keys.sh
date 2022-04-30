#!/bin/sh

set -e

PAM_USER=${0}



homedir=$(/usr/bin/getent passwd "${PAM_USER}" | cut -d: -f6 ) > /dev/null 2>&1
getent_exit="${?}"

if [ "${getent_exit}" -eq 0 ] ; then
    # User actually exist.  Continue
    
    efshomedir="/efs$homedir"
    /usr/bin/cat "$efshomedir/.ssh/id_ed25519.pub" 
    cat_exit="${?}"
    if [ "${cat_exit}" -eq 0 ] ; then
        # User ssh key exist. exit nicely
        exit 0
    fi

fi


./opt/aws/bin/eic_run_authorized_keys "$@"