#!/usr/bin/env bash

set -e

allowedDomains="DOMAINS"

for domain in ${allowedDomains//,/ }
do

        stateUrl="https://s3.amazonaws.com/public-gws-aws.$domain"

        statePath="/etc/pam_scripts/users/$domain-state.json"
        userStatePath="/etc/pam_scripts/users/$domain-users.json"
        lastSync="/etc/pam_scripts/users/$domain-lastSync.txt"

        # get data
        curl $stateUrl/data/state.json -S -s -o $statePath
        curl $stateUrl/data/users.json -S -s -o $userStatePath

        # check if there is a difference
        LocalLastSync=$(/usr/bin/echo -n > $lastSync && cat $lastSync || /usr/bin/echo "")
        RemoteLastSync=$(jq -r .lastSync $statePath)

        if [[ "${LocalLastSync}" != "" ]] ;then
            if [[ "${LocalLastSync}" == "${RemoteLastSync}" ]] ;then
                /usr/bin/echo "Local and remote sync matches"
                exit 0
            fi
        fi


        count=`jq '.users | length' "$userStatePath"`
        for ((i=0; i<$count; i++)); do
            email=`jq -r '.users['$i'].email // empty' "$userStatePath"`
            hashCode=`jq -r '.users['$i'].hashCode // empty' "$userStatePath"`
            ipid=`jq -r '.users['$i'].ipid // empty' "$userStatePath"`
            hashCodePath="/etc/pam_scripts/users/$hashCode.txt"

            uuid=$(/usr/bin/echo "$ipid" | cut -c -5)
            username=$(/usr/bin/echo $email | cut -d@ -f1)
            fulldomain=$(/usr/bin/echo  $email | cut -d@ -f2)
            loginUsername="$domain-$username"
            homeDir="/home/$loginUsername"
            workspaceDir="/workspace/$loginUsername"

            rm -f "$homeDir/authorized_keys"
            
            if [[ ! -f "$hashCodePath" ]]; then
                # add user 
                /usr/sbin/groupadd -g $uuid $loginUsername || true
                /usr/sbin/useradd $loginUsername -u $uuid -g $uuid -m -s /bin/bash || true

                # set git config
                /usr/bin/echo -n > "$homeDir/.gitconfig"
                /usr/bin/echo "[user]" >> "$homeDir/.gitconfig"
                /usr/bin/echo "      name = $username" >> "$homeDir/.gitconfig"
                /usr/bin/echo "      email = $email" >> "$homeDir/.gitconfig"

                # create workspace
                /usr/bin/mkdir -p "$homeDir/.aws"
                /usr/bin/mkdir -p "$homeDir/.gcloud"
                #/usr/bin/mkdir -p "$homeDir/containers/.devcontainer"


                # add envs
                /usr/bin/touch "$homeDir/.bashrc"
                /usr/bin/echo "export USER_NAME=$loginUsername" >> "$homeDir/.bashrc"
                /usr/bin/echo "export USER_DOMAIN=$domain" >> "$homeDir/.bashrc"
                /usr/bin/echo "export USER_FULLDOMAIN=$fulldomain" >> "$homeDir/.bashrc"
                /usr/bin/echo "export USER_EMAIL=$email" >> "$homeDir/.bashrc"
                /usr/bin/echo "export USER_WORKSPACE=$workspaceDir" >> "$homeDir/.bashrc"


                # auto start ssh agent
                /usr/bin/echo "" >> "$homeDir/.bash_profile"
                /usr/bin/cat "/tmp/docker-master/devboxes/bash_scripts/ssh_agent.sh" >> "$homeDir/.bash_profile"

                # user start up script
                /usr/bin/echo "" >> "$homeDir/.bash_profile"
                /usr/bin/echo "bash /usr/local/bin/workspace-one-time-startup.sh" >> "$homeDir/.bash_profile"

                # ssh
                /usr/bin/mkdir -p "$homeDir/.ssh"
                /usr/bin/chmod 700 "$homeDir/.ssh"

                # make sure all files belong to user
                /usr/bin/chown "$loginUsername":"$loginUsername"  -R "$homeDir"


                # add user to docker group
                /usr/sbin/usermod -aG docker $loginUsername || true
                
                /usr/bin/echo -n > "$hashCodePath"
            fi
        done

        # update lastSync
        /usr/bin/curl -s $stateUrl/data/state.json | jq -r '.lastSync' > $lastSync

done