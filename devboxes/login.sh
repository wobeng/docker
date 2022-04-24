#!/bin/bash
set -e

username=$(/usr/bin/echo $PAM_USER | cut -d@ -f1)
domain=$(/usr/bin/echo $PAM_USER | cut -d. -f1 | cut -d@ -f2)
fulldomain=$(/usr/bin/echo  $PAM_USER | cut -d@ -f2)
homedir=$(/usr/bin/getent passwd $username | cut -d: -f6)
userid=$(/usr/bin/id -u $PAM_USER)
efshomedir="/efs$homedir"

if [ "$username" == "root" ] || [ "$username" == "ec2-user" ]; then
    /usr/bin/echo "Nothing to do for $username"
    exit 0
fi

# mount user efs
if ! /usr/bin/grep -qxF "EFS_ID:$homedir $homedir efs _netdev,noresvport,tls,iam 0 0" /etc/fstab
then
    mkdir -p "$efshomedir"
    mkdir -p "/tmp/$userid"
    /usr/bin/rsync -a $homedir/ $efshomedir
    echo "export TMPDIR=/tmp/$userid" >> "$efshomedir/.bashrc"
    echo "export USER_EMAIL=$PAM_USER" >> "$efshomedir/.bashrc"
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

# add user to docker group
/usr/sbin/usermod -aG docker $username
/usr/sbin/usermod -aG docker $PAM_USER


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