#!/usr/bin/env bash
set -e


if  [ "$PAM_USER" == "root" ] || [ "$PAM_USER" == "ec2-user" ]; then
   /usr/bin/echo "Nothing to do for $PAM_USER"
    exit 0
fi


if [ ! -n "$PAM_USER" ]; then
  /usr/bin/echo "Please set \$username"
  exit 0
fi

username=$username
homedir="/home/$username"
workspacedir="/workspace/$username"

# mount user efs home directory
if ! /usr/bin/grep -qxF "EFS_ID:$homedir $homedir efs _netdev,noresvport,tls,iam 0 0" /etc/fstab
then
    # mount
    /usr/bin/mount -t efs -o tls,iam EFS_ID:"$homedir" "$homedir"
    /usr/bin/echo "EFS_ID:$homedir $homedir efs _netdev,noresvport,tls,iam 0 0" >> /etc/fstab

fi

# mount user efs workspace directory
if ! /usr/bin/grep -qxF "EFS_ID:$workspacedir $workspacedir efs _netdev,noresvport,tls,iam 0 0" /etc/fstab
then
    # mount
    /usr/bin/mount -t efs -o tls,iam EFS_ID:"$workspacedir" "$workspacedir"
    /usr/bin/echo "EFS_ID:$workspacedir $workspacedir efs _netdev,noresvport,tls,iam 0 0" >> /etc/fstab

fi

# make sure there is a ssh key
if [ ! -f "$homedir/.ssh/id_ed25519" ]; then
    /usr/bin/ssh-keygen -q -t ed25519 -N '' -f "$homedir/.ssh/id_ed25519" -C "$username" <<<y >/dev/null 2>&1
    {
        /usr/bin/echo "Host *"
        /usr/bin/echo " AddKeysToAgent yes"
        /usr/bin/echo " ForwardAgent yes"
        /usr/bin/echo " IdentityFile $homedir/.ssh/id_ed25519"
    } >> "$homedir/.ssh/config"

fi