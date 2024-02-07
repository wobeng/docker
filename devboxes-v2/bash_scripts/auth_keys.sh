#!/bin/sh
# This script is used to check user public key
set -e

domain=$(/usr/bin/echo ${1}| cut -d- -f1)
username=$(/usr/bin/echo ${1}| cut -d- -f2)

statePath="/etc/pam_scripts/users/$domain-state.json"
stateUsersPath="/etc/pam_scripts/users/$domain-users.json"

exit_nicely()
{
    /usr/bin/timeout 5s "/opt/aws/bin/eic_run_authorized_keys" "$@" 
    exit 0
}

datetime=$(jq -r .lastSync $statePath)
if [ $? -ne 0 ]; then
    exit_nicely "$@"
fi

timeago='15 min ago'
dtSec=$(date --date "$datetime" +'%s') 
taSec=$(date --date "$timeago" +'%s')

if [ $dtSec -lt $taSec  ]; then
    echo "sync is too old"
    exit_nicely "$@"
fi

email=$(cat $stateUsersPath | jq -r ".users[] | select(.email | startswith(\"$username@\")) | .email")
if [ $? -ne 0 ]; then
    echo "unauthorized: sending client infomation to server...."
    exit_nicely "$@"
fi

fulldomain=$(echo "${email#*@}")
stateUrl="s3://public-gws-aws.$fulldomain"
pubkey=$(aws s3 cp $stateUrl/users/keys/${email}.pub - )
if [ $? -ne 0 ]; then
    echo "something went wrong with pub key"
    exit_nicely "$@"
fi


/usr/bin/echo "$pubkey"
