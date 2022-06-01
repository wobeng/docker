 #!/bin/bash
set -e

for item in ${DOMAINS//,/ }
do

        domain=$(/usr/bin/echo ${item}| cut -d. -f1 | cut -d@ -f2)
        fulldomain=$(/usr/bin/echo  ${item} | cut -d@ -f2)

        stateUrl="https://s3.amazonaws.com/public-gws-aws.$fulldomain"

        statePath="/etc/pam_scripts/users/$domain-state.json"
        userStatePath="/etc/pam_scripts/users/$domain-users.json"
        lastSync="/etc/pam_scripts/users/$domain-lastSync.txt"

        # get data
        curl $stateUrl/data/state.json -S -s -o $statePath
        curl $stateUrl/data/users.json -S -s -o $userStatePath

        # check if there is a difference
        LocalLastSync=$(cat $lastSync || echo "")
        RemoteLastSync=$(jq -r .lastSync $statePath)

        if [[ "${LocalLastSync}" != "" ]] ;then
            if [[ "${LocalLastSync}" == "${RemoteLastSync}" ]] ;then
                echo "Local and remote sync matches"
                exit 0
            fi
        fi


        count=`jq '.users | length' "$userStatePath"`
        for ((i=0; i<$count; i++)); do
            email=`jq -r '.users['$i'].email // empty' "$userStatePath"`
            hashCode=`jq -r '.users['$i'].hashCode // empty' "$userStatePath"`
            hashCodePath="/etc/pam_scripts/users/$hashCode.txt"

            username=$(/usr/bin/echo $email | cut -d@ -f1)
            loginUsername="$username-$domain"

            if [[ ! -f "$hashCodePath" ]]; then
                useradd "$loginUsername"  || echo "======================="
                touch "$hashCodePath"
            fi
        done

        # update lastSync
        curl  -s $stateUrl/data/state.json | jq -r '.lastSync' > $lastSync

done