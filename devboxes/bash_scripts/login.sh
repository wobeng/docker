#!/bin/bash
set -e


if  [ "$PAM_USER" == "root" ] || [ "$PAM_USER" == "ec2-user" ]; then
    /usr/bin/echo "Nothing to do for $PAM_USER"
    exit 0
fi


if [ ! -n "$PAM_USER" ]; then
  echo "Please set \$PAM_USER"
  exit 0
fi


username=$(/usr/bin/echo $PAM_USER | cut -d@ -f1)
domain=$(/usr/bin/echo $PAM_USER | cut -d. -f1 | cut -d@ -f2)
fulldomain=$(/usr/bin/echo  $PAM_USER | cut -d@ -f2)
homedir=$(/usr/bin/getent passwd $PAM_USER | cut -d: -f6)
userid=$(/usr/bin/id -u $PAM_USER)
efshomedir="/efs$homedir"

# mount user efs and first time process
if ! /usr/bin/grep -qxF "EFS_ID:$homedir $homedir efs _netdev,noresvport,tls,iam 0 0" /etc/fstab
then

    # add user to docker group
    /usr/sbin/usermod -aG docker $username

    # set git config
    touch "$homedir/.gitconfig"
    echo "[user]" >> "$homedir/.gitconfig"
    echo "      name = $username" >> "$homedir/.gitconfig"
    echo "      email = $PAM_USER" >> "$homedir/.gitconfig"

    # create workspace
    mkdir -p "$homedir/.aws"
    mkdir -p "$homedir/.gcloud"
    mkdir -p "$homedir/containers/.devcontainer"
    chown "$PAM_USER":"$PAM_USER"  -R "$homedir/containers"

    mkdir -p "/workspaces/$fulldomain/$username"
    chmod 700 "/workspaces/$fulldomain/$username"
    chown "$PAM_USER":"$PAM_USER" "/workspaces/$fulldomain/$username"

    # add envs
    touch "$homedir/.bashrc"
    echo "export USER_ID=$userid" >> "$homedir/.bashrc"
    echo "export USER_NAME=$username" >> "$homedir/.bashrc"
    echo "export USER_DOMAIN=$domain" >> "$homedir/.bashrc"
    echo "export USER_FULLDOMAIN=$fulldomain" >> "$homedir/.bashrc"
    echo "export USER_EMAIL=$PAM_USER" >> "$homedir/.bashrc"
    echo "export USER_WORKSPACE=/workspaces/$fulldomain/$username" >> "$homedir/.bashrc"


    # auto start ssh agent
    echo "" >> "$homedir/.bash_profile"
    /usr/bin/cat "/tmp/docker-master/devboxes/bash_scripts/ssh_agent.sh" >> "$homedir/.bash_profile"

    # user start up script
    echo "" >> "$homedir/.bash_profile"
    echo "bash /usr/local/bin/workspace-one-time-startup.sh" >> "$homedir/.bash_profile"

    # mount
    mkdir -p "$efshomedir"
    /usr/bin/rsync -a --ignore-existing --include='.bash*' --exclude='*' $homedir/ $efshomedir/
    chown "$PAM_USER":"$PAM_USER" -R "$efshomedir"
    /usr/bin/mount -t efs -o tls,iam EFS_ID:"$homedir" "$homedir"
    echo "EFS_ID:$homedir $homedir efs _netdev,noresvport,tls,iam 0 0" >> /etc/fstab

fi

# make sure there is a ssh key
if [ ! -f "$homedir/.ssh/id_ed25519" ]; then
    mkdir -p "$homedir/.ssh"
    touch "$homedir/.ssh/config"
    touch "$homedir/.ssh/authorized_keys"
    /usr/bin/ssh-keygen -q -t ed25519 -N '' -f "$homedir/.ssh/id_ed25519" -C "$PAM_USER" <<<y >/dev/null 2>&1
    /usr/bin/cat "$homedir/.ssh/id_ed25519.pub" > "$homedir/.ssh/authorized_keys"
    {
        echo "Host *"
        echo " AddKeysToAgent yes"
        echo " ForwardAgent yes"
        echo " IdentityFile $homedir/.ssh/id_ed25519"
    } >> "$homedir/.ssh/config"

fi

# make sure user can always login
chmod 700 "$homedir/.ssh"
chmod 600 "$homedir/.ssh/config"
chmod 600 "$homedir/.ssh/authorized_keys"
chown "$PAM_USER":"$PAM_USER"  -R "$homedir/.ssh"
