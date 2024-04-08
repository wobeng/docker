#!/usr/bin/env bash

set -e


allowedDomains="DOMAINS"
instanceName="INSTANCE_NAME"
instanceDomain="INSTANCE_DOMAIN"

IP=0.0.0.0
first_port=55535
last_port=65535


for fulldomain in ${allowedDomains//,/ }
do
        stateUrl="s3://public-gws-aws.$fulldomain"

        # remove dot from domain
        domain=${fulldomain//./}
        
        statePath="/etc/pam_scripts/users/$domain-state.json"
        userStatePath="/etc/pam_scripts/users/$domain-users.json"
        lastSync="/etc/pam_scripts/users/$domain-lastSync.txt"

        # get data
        aws s3 cp $stateUrl/data/state.json $statePath || continue
        aws s3 cp $stateUrl/data/devboxes/${instanceName}.json $userStatePath || continue

        # don't outside users of allowed domains
        find /data/home -name "authorized_keys" -type f -delete

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
            loginUsername="$domain-$username"
            homeDir="/data/home/$loginUsername"
            workspaceDir="/data/workspace/$loginUsername"

            # only execute if user does not exist on the server
            if [[ ! -f "$hashCodePath" ]]; then
                # add user 
                /usr/sbin/groupadd -g $uuid $loginUsername || true
                /usr/sbin/useradd $loginUsername -u $uuid -g $uuid -m -d $homeDir -s /bin/bash || true

                # set git config
                /usr/bin/echo -n > "$homeDir/.gitconfig"
                /usr/bin/echo "[user]" >> "$homeDir/.gitconfig"
                /usr/bin/echo "      name = $username" >> "$homeDir/.gitconfig"
                /usr/bin/echo "      email = $email" >> "$homeDir/.gitconfig"

                # create directories
                /usr/bin/mkdir -p "$homeDir/.aws"
                /usr/bin/mkdir -p "$homeDir/.gcloud"
                /usr/bin/mkdir -p "$workspaceDir"
                /usr/bin/mkdir -p "$workspaceDir/repos"
                /usr/bin/mkdir -p "$workspaceDir/extras"
                /usr/bin/mkdir -p "$workspaceDir/configs/envs"
                /usr/bin/mkdir -p "$workspaceDir/configs/installs"
                /bin/ln -s "$homeDir/.aws" $workspaceDir/configs/aws
                /bin/ln -s "$homeDir/.gcloud" $workspaceDir/configs/gcloud
                /usr/bin/touch $workspaceDir/configs/envs/dev


                # add envs
                /usr/bin/touch "$homeDir/.bashrc"
                /usr/bin/echo "export USER_NAME=$loginUsername" >> "$homeDir/.bashrc"
                /usr/bin/echo "export USER_FULLDOMAIN=$fulldomain" >> "$homeDir/.bashrc"
                /usr/bin/echo "export USER_EMAIL=$email" >> "$homeDir/.bashrc"
                /usr/bin/echo "export USER_WORKSPACE=$workspaceDir" >> "$homeDir/.bashrc"

                # reserve ports and set up nginx
                bash  /etc/pam_scripts/assign_ports.sh $loginUsername $homeDir "${instanceName}.${instanceDomain}"
                /usr/bin/systemctl restart nginx

                # auto start ssh agent
                /usr/bin/echo "" >> "$homeDir/.bash_profile"
                /usr/bin/cat "/etc/pam_scripts/ssh_agent.sh" >> "$homeDir/.bash_profile"

                # ssh
                /usr/bin/mkdir -p "$homeDir/.ssh"
                /usr/bin/chmod 700 "$homeDir/.ssh"

                # make sure all files belong to user
                /usr/bin/chown "$loginUsername":"$loginUsername"  -R "$homeDir"
                /usr/bin/chown "$loginUsername":"$loginUsername"  -R "$workspaceDir"

                # add user to docker group
                /usr/sbin/usermod -aG docker $loginUsername || true
                
                /usr/bin/echo -n > "$hashCodePath"
            fi
        done

        # update lastSync
        aws s3 cp $stateUrl/data/state.json - | jq -r '.lastSync' > $lastSync

done
