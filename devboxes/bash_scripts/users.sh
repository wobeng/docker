 #!/bin/bash
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
        LocalLastSync=$(/usr/bin/touch $lastSync && cat $lastSync || echo "")
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
            ipid=`jq -r '.users['$i'].ipid // empty' "$userStatePath"`
            hashCodePath="/etc/pam_scripts/users/$hashCode.txt"

            uuid=$(/usr/bin/echo "$ipid" | cut -c -5)
            username=$(/usr/bin/echo $email | cut -d@ -f1)
            fulldomain=$(/usr/bin/echo  $email | cut -d@ -f2)
            loginUsername="$domain-$username"
            homeDir="/home/$loginUsername"
            workspaceDir="/workspace/$loginUsername"
            efsHomeDir="/efs$homeDir"
            efsWorkspaceDir="/efs/$workspaceDir"

            rm -f "$homeDir/authorized_keys"
            
            if [[ ! -f "$hashCodePath" ]]; then
                # add user 
                /usr/sbin/groupadd -g $uuid $loginUsername || true
                /usr/sbin/useradd $loginUsername -u $uuid -g $uuid -m -s /bin/bash || true

                # add user to docker group
                /usr/sbin/usermod -aG docker $loginUsername || true

                # set git config
                /usr/bin/touch "$homeDir/.gitconfig"
                echo "[user]" >> "$homeDir/.gitconfig"
                echo "      name = $username" >> "$homeDir/.gitconfig"
                echo "      email = $email" >> "$homeDir/.gitconfig"

                # create workspace
                /usr/bin/mkdir -p "$homeDir/.aws"
                /usr/bin/mkdir -p "$homeDir/.gcloud"
                /usr/bin/mkdir -p "$homeDir/containers/.devcontainer"

                /usr/bin/mkdir -p "$workspaceDir"
                chmod 700 "$workspaceDir"

                # add envs
                /usr/bin/touch "$homeDir/.bashrc"
                echo "export USER_NAME=$loginUsername" >> "$homeDir/.bashrc"
                echo "export USER_DOMAIN=$domain" >> "$homeDir/.bashrc"
                echo "export USER_FULLDOMAIN=$fulldomain" >> "$homeDir/.bashrc"
                echo "export USER_EMAIL=$email" >> "$homeDir/.bashrc"
                echo "export USER_WORKSPACE=$workspaceDir" >> "$homeDir/.bashrc"


                # auto start ssh agent
                echo "" >> "$homeDir/.bash_profile"
                /usr/bin/cat "/tmp/docker-master/devboxes/bash_scripts/ssh_agent.sh" >> "$homeDir/.bash_profile"

                # user start up script
                echo "" >> "$homeDir/.bash_profile"
                echo "bash /usr/local/bin/workspace-one-time-startup.sh" >> "$homeDir/.bash_profile"

                # ssh
                /usr/bin/mkdir -p "$homeDir/.ssh"
                /usr/bin/touch "$homeDir/.ssh/config"
                chmod 700 "$homeDir/.ssh"
                chmod 600 "$homeDir/.ssh/config"

                # prepare mount
                /usr/bin/mkdir -p "$efsHomeDir"
                /usr/bin/mkdir -p "$efsWorkspaceDir"
                /usr/bin/rsync -a --ignore-existing --include='.bash*' --exclude='*' $homeDir/ $efsHomeDir/

                /usr/bin/chown "$loginUsername":"$loginUsername"  -R "$homeDir"
                /usr/bin/chown "$loginUsername":"$loginUsername" -R "$workspaceDir"
                /usr/bin/chown "$loginUsername":"$loginUsername" -R "$efsHomeDir"
                /usr/bin/chown "$loginUsername":"$loginUsername" -R "$efsWorkspaceDir"

                
                /usr/bin/touch "$hashCodePath"
            fi
        done

        # update lastSync
        curl  -s $stateUrl/data/state.json | jq -r '.lastSync' > $lastSync

done