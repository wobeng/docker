#!/bin/bash
set -e


if  [ "$PAM_USER" == "root" ] || [ "$PAM_USER" == "ec2-user" ]; then
    /usr/bin/echo "Nothing to do for $PAM_USER"
    exit 0
fi


if [ ! -n "$PAM_USER" ]; then
  echo "Please set $PAM_USER"
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
    /usr/sbin/usermod -aG docker $PAM_USER

    # create workspace
    mkdir -p "/workspaces/$fulldomain/$PAM_USER"
    chmod 700 "/workspaces/$fulldomain/$PAM_USER"
    chown "$userid":"$userid" -R "/workspaces/$fulldomain/$PAM_USER"

    # add envs
    touch "$homedir/.bashrc"
    echo "export USER_EMAIL=$PAM_USER" >> "$homedir/.bashrc"
    echo "export USER_ID=$userid" >> "$homedir/.bashrc"

    # auto start ssh agent
    /usr/bin/wget -O  "/tmp/ssh_agent.sh" https://raw.githubusercontent.com/wobeng/docker/master/devboxes/bash_scripts/ssh_agent.sh
    echo "" >> "$homedir/.bash_profile"
    /usr/bin/cat "/tmp/ssh_agent.sh" >> "$homedir/.bash_profile"

    # mount
    mkdir -p "$efshomedir"
    /usr/bin/rsync -a --ignore-existing --include='.bash*' --exclude='*' $homedir/ $efshomedir/
    chown "$userid":"$userid" -R "$efshomedir"
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
chown "$userid":"$userid"  -R "$homedir/.ssh"

# make containers
mkdir -p "$homedir/containers/.devcontainer"
chown "$userid":"$userid"  -R "$homedir/containers"
if [ ! -f "$homedir/containers/.devcontainer/devcontainer.json" ]; then
    /usr/bin/wget -O  "$homedir/containers/.devcontainer/devcontainer.json" https://raw.githubusercontent.com/wobeng/docker/master/devboxes/devcontainer.json
fi
