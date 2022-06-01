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
            fulldomain=$(/usr/bin/echo  $email | cut -d@ -f2)
            loginUsername="$domain-$username"
            homeDir="/home/$loginUsername"

            rm -f "$homeDir/authorized_keys"
            
            if [[ ! -f "$hashCodePath" ]]; then
                # add user 
                /usr/sbin/adduser $loginUsername || true
                # add user to docker group
                /usr/sbin/usermod -aG docker $loginUsername || true

                # set git config
                touch "$homeDir/.gitconfig"
                echo "[user]" >> "$homeDir/.gitconfig"
                echo "      name = $username" >> "$homeDir/.gitconfig"
                echo "      email = $email" >> "$homeDir/.gitconfig"

                # create workspace
                /usr/bin/mkdir -p "$homeDir/.aws"
                /usr/bin/mkdir -p "$homeDir/.gcloud"
                /usr/bin/mkdir -p "$homeDir/containers/.devcontainer"
                /usr/bin/chown "$loginUsername":"$loginUsername"  -R "$homeDir/containers"

                /usr/bin/mkdir -p "/workspaces/$loginUsername"
                chmod 700 "/workspaces/$loginUsername"
                /usr/bin/chown "$loginUsername":"$loginUsername" "/workspaces/$loginUsername"

                # add envs
                touch "$homeDir/.bashrc"
                echo "export USER_NAME=$loginUsername" >> "$homeDir/.bashrc"
                echo "export USER_DOMAIN=$domain" >> "$homeDir/.bashrc"
                echo "export USER_FULLDOMAIN=$fulldomain" >> "$homeDir/.bashrc"
                echo "export USER_EMAIL=$email" >> "$homeDir/.bashrc"
                echo "export USER_WORKSPACE=/workspaces/$loginUsername" >> "$homeDir/.bashrc"


                # auto start ssh agent
                echo "" >> "$homeDir/.bash_profile"
                /usr/bin/cat "/tmp/docker-master/devboxes/bash_scripts/ssh_agent.sh" >> "$homeDir/.bash_profile"

                # user start up script
                echo "" >> "$homeDir/.bash_profile"
                echo "bash /usr/local/bin/workspace-one-time-startup.sh" >> "$homeDir/.bash_profile"

                touch "$hashCodePath"
            fi
        done

        # update lastSync
        curl  -s $stateUrl/data/state.json | jq -r '.lastSync' > $lastSync

done