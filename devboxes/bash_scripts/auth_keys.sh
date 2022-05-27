#!/bin/sh
set -e

username=$(/usr/bin/echo ${1} | cut -d@ -f1)
fulldomain=$(/usr/bin/echo  ${1} | cut -d@ -f2)
url="https://s3.amazonaws.com/public-gws-aws.$fulldomain"


datetime=$(curl --fail-with-body -s $url/data/state.json | jq -r '.lastSync')

if [ $? -ne 0 ]; then
    /usr/bin/timeout 5s "/opt/aws/bin/eic_run_authorized_keys" "$@" 
    exit 0
fi

timeago='10 min ago'
dtSec=$(date --date "$datetime" +'%s') 
taSec=$(date --date "$timeago" +'%s')

if [ $dtSec -lt $taSec  ]; then
    echo "sync is too old"
    exit 1
fi


pubkey=$(curl --fail-with-body -s $url/users/keys/$username.pub)
if [ $? -ne 0 ]; then
    echo "something went wrong with pub key"
    exit 1
fi


/usr/bin/cat "$pubkey"
