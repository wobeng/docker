#!/bin/bash
set -e

username=$(/usr/bin/echo $PAM_USER | cut -d@ -f1)
domain=$(/usr/bin/echo $PAM_USER | cut -d. -f1 | cut -d@ -f2)
fulldomain=$(/usr/bin/echo  $PAM_USER | cut -d@ -f2)
homedir=$(/usr/bin/getent passwd $username | cut -d: -f6)
efshomedir="/efs$homedir"

if [ "$username" == "root" ] || [ "$username" == "ec2-user" ]; then
    /usr/bin/echo "Nothing to do for $username"
    exit 0
fi

# add user to docker group
/usr/sbin/usermod -aG docker $username

# mount user efs
if ! /usr/bin/grep -qxF "EFS_ID:$homedir $homedir efs _netdev,noresvport,tls,iam 0 0" /etc/fstab
then
    mkdir -p "$efshomedir"
    /usr/bin/rsync -a $homedir/ $efshomedir
    echo "export USER_EMAIL=$PAM_USER" >> "$efshomedir/.bashrc"
    chown "$PAM_USER":"$PAM_USER" -R "$efshomedir"
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
        echo " UseKeychain yes"
    } >>~/.ssh/config
    chmod 700 "$homedir/.ssh"
    chmod 600 "$homedir/.ssh/config"
    chmod 600 "$homedir/.ssh/authorized_keys"
    chown "$PAM_USER":"$PAM_USER" -R "$homedir/.ssh"
fi
