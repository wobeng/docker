#!/usr/bin/env bash
set -e


if  [ "$PAM_USER" == "root" ] || [ "$PAM_USER" == "ec2-user" ]; then
    /usr/bin/echo "Nothing to do for $PAM_USER"
    exit 0
fi


if [ ! -n "$PAM_USER" ]; then
  echo "Please set \$username"
  exit 0
fi

username=$username
homedir="/home/$username"
efshomedir="/efs$homedir"

# mount user efs and first time process
if ! /usr/bin/grep -qxF "EFS_ID:$homedir $homedir efs _netdev,noresvport,tls,iam 0 0" /etc/fstab
then

    # mount
    /usr/bin/mkdir -p "$efshomedir"
    /usr/bin/rsync -a --ignore-existing --include='.bash*' --exclude='*' $homedir/ $efshomedir/
    /usr/bin/chown "$username":"$username" -R "$efshomedir"
    /usr/bin/mount -t efs -o tls,iam EFS_ID:"$homedir" "$homedir"
    echo "EFS_ID:$homedir $homedir efs _netdev,noresvport,tls,iam 0 0" >> /etc/fstab

fi

# make sure there is a ssh key
if [ ! -f "$homedir/.ssh/id_ed25519" ]; then
    /usr/bin/mkdir -p "$homedir/.ssh"
    touch "$homedir/.ssh/config"
    /usr/bin/ssh-keygen -q -t ed25519 -N '' -f "$homedir/.ssh/id_ed25519" -C "$username" <<<y >/dev/null 2>&1
    {
        echo "Host *"
        echo " AddKeysToAgent yes"
        echo " ForwardAgent yes"
        echo " IdentityFile $homedir/.ssh/id_ed25519"
    } >> "$homedir/.ssh/config"

fi