#!/bin/bash
set -e


if  [ "$PAM_USER" == "root" ] || [ "$PAM_USER" == "ec2-user" ]; then
    /usr/bin/echo "Nothing to do for $username"
    exit 0
fi


if [ ! -n "$PAM_USER" ]; then
  echo "Please set $PAM_USER"
  exit 0
fi


username=$(/usr/bin/echo $PAM_USER | cut -d@ -f1)
domain=$(/usr/bin/echo $PAM_USER | cut -d. -f1 | cut -d@ -f2)
fulldomain=$(/usr/bin/echo  $PAM_USER | cut -d@ -f2)
homedir=$(/usr/bin/getent passwd $username | cut -d: -f6)
userid=$(/usr/bin/id -u $PAM_USER)
efshomedir="/efs$homedir"

# mount user efs and first time process
if ! /usr/bin/grep -qxF "EFS_ID:$homedir $homedir efs _netdev,noresvport,tls,iam 0 0" /etc/fstab
then

    # add user to docker group
    /usr/sbin/usermod -aG docker $username
    /usr/sbin/usermod -aG docker $PAM_USER

    # add envs
    mkdir -p "/tmp/$userid"
    chown "$userid":"$userid" -R "/tmp/$userid"
    echo "export TMPDIR=/tmp/$userid" >> "$homedir/.bashrc"
    echo "export USER_EMAIL=$PAM_USER" >> "$homedir/.bashrc"

    # auto start ssh agent
    /usr/bin/wget -O  "/tmp/ssh_agent.sh" https://raw.githubusercontent.com/wobeng/docker/master/devboxes/ssh_agent.sh
    echo "" >> "$homedir/.bash_profile"
    /usr/bin/cat "/tmp/ssh_agent.sh" >> "$homedir/.bash_profile"

    # mount
    mkdir -p "$efshomedir"
    /usr/bin/rsync -a --include='.*' --exclude='*' $homedir/ $efshomedir/
    chown "$userid":"$userid" -R "$efshomedir"
    /usr/bin/mount -t efs -o tls,iam EFS_ID:"$homedir" "$homedir"
    echo "EFS_ID:$homedir $homedir efs _netdev,noresvport,tls,iam 0 0" >> /etc/fstab

fi

# make sure there is a ssh key
if [ ! -f "$homedir/.ssh/ed25519_$domain" ]; then
    mkdir -p "$homedir/.ssh"
    touch "$homedir/.ssh/config"
    touch "$homedir/.ssh/authorized_keys"
    /usr/bin/ssh-keygen -q -t ed25519 -N '' -f "$homedir/.ssh/ed25519_$domain" -C "$PAM_USER" <<<y >/dev/null 2>&1
    /usr/bin/cat "$homedir/.ssh/ed25519_$domain.pub" > "$homedir/.ssh/authorized_keys"
    {
        echo "Host *"
        echo " IdentityFile $homedir/.ssh/ed25519_$domain"
        echo " AddKeysToAgent yes"
    } >> "$homedir/.ssh/config"
fi

# make sure user can always login
chmod 700 "$homedir/.ssh"
chmod 600 "$homedir/.ssh/config"
chmod 600 "$homedir/.ssh/authorized_keys"
chown "$userid":"$userid"  -R "$homedir/.ssh"

# make devboxes
mkdir -p "$homedir/devbox/.devcontainer"
chown "$userid":"$userid"  -R "$homedir/devbox"
if [ ! -f "$homedir/devbox/.devcontainer/devcontainer.json" ]; then
    /usr/bin/wget -O  "$homedir/devbox/.devcontainer/devcontainer.json" https://raw.githubusercontent.com/wobeng/docker/master/devboxes/devcontainer.json
fi
