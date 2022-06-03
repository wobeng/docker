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

username=$PAM_USER
homeDir="/home/$username"
workspaceDir="/workspace/$username"
efsHomeDir="/efs$homeDir"
efsWorkspaceDir="/efs/$workspaceDir"

# mount user efs home directory
if ! /usr/bin/grep -qxF "EFS_ID:$homeDir $homeDir efs _netdev,noresvport,tls,iam 0 0" /etc/fstab
then
    # create efs home dir
    /usr/bin/mkdir -p "$efsHomeDir"
    /usr/bin/chmod 700 "$efsHomeDir"
    /usr/bin/chown "$username":"$username" -R "$efsHomeDir"

    /usr/bin/rsync  -a --ignore-times $homeDir/ $efsHomeDir/
    /usr/bin/mount -t efs -o tls,iam EFS_ID:"$homeDir" "$homeDir"
    /usr/bin/echo "EFS_ID:$homeDir $homeDir efs _netdev,noresvport,tls,iam 0 0" >> /etc/fstab

fi

# mount user efs workspace directory
if ! /usr/bin/grep -qxF "EFS_ID:$workspaceDir $workspaceDir efs _netdev,noresvport,tls,iam 0 0" /etc/fstab
then
    # create workspace dir
    /usr/bin/mkdir -p "$workspaceDir"
    /usr/bin/chmod 700 "$workspaceDir"
    /usr/bin/chown "$username":"$username" -R "$workspaceDir"

    # create efs workspace dir
    /usr/bin/mkdir -p "$efsWorkspaceDir"
    /usr/bin/chmod 700 "$efsWorkspaceDir"
    /usr/bin/chown "$username":"$username" -R "$efsWorkspaceDir"

    /usr/bin/mount -t efs -o tls,iam EFS_ID:"$workspaceDir" "$workspaceDir"
    /usr/bin/echo "EFS_ID:$workspaceDir $workspaceDir efs _netdev,noresvport,tls,iam 0 0" >> /etc/fstab

fi

# make sure there is a ssh key
if [ ! -f "$homeDir/.ssh/id_ed25519" ]; then
    /usr/bin/ssh-keygen -q -t ed25519 -N '' -f "$homeDir/.ssh/id_ed25519" -C "$username" <<<y >/dev/null 2>&1
    {
        /usr/bin/echo "Host *"
        /usr/bin/echo " AddKeysToAgent yes"
        /usr/bin/echo " ForwardAgent yes"
        /usr/bin/echo " IdentityFile $homeDir/.ssh/id_ed25519"
    } >> "$homeDir/.ssh/config"

fi