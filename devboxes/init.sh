#!/bin/bash

set -e

# update the system and install packages
sudo yum update -y && sudo yum install -y rsync jq amazon-efs-utils git zip unzip sssd sssd-tools sssd-ldap openldap-clients rsync

# set up python
python3  --version
python3 -m pip install botocore

# start ssm
sudo systemctl enable amazon-ssm-agent
sudo systemctl start amazon-ssm-agent

# mount efs
if ! grep -qxF "$EFS_ID:/ /efs efs _netdev,noresvport,tls,iam 0 0" /etc/fstab
then

    sudo mkdir -p /efs/home
    mount -t efs -o tls,iam "$EFS_ID":/ /efs
    echo "$EFS_ID:/ /efs efs _netdev,noresvport,tls,iam 0 0" >> /etc/fstab
    
    #ensure all ssh keys are the same
    /usr/bin/rsync -a --ignore-times  --include='ssh_host_*'  --exclude='*' /efs/host_ssh_keys/ /etc/ssh/
fi


# Install docker and mount docker volumes to efs
if ! grep -qxF "$EFS_ID:/docker/volumes /var/lib/docker/volumes efs _netdev,noresvport,tls,iam 0 0" /etc/fstab

then
    sudo amazon-linux-extras install docker -y
    /usr/bin/rsync -a  /var/lib/docker/volumes/ /efs/docker/volumes/
    mount -t efs -o tls,iam "$EFS_ID":/docker/volumes /var/lib/docker/volumes
    echo "$EFS_ID:/docker/volumes /var/lib/docker/volumes efs _netdev,noresvport,tls,iam 0 0" >> /etc/fstab

fi

sudo systemctl enable docker
sudo systemctl restart docker
sudo usermod -aG docker ec2-user    


# add user script
sudo mkdir -p /etc/pam_scripts
wget -O  /etc/pam_scripts/login-logger.sh https://raw.githubusercontent.com/wobeng/docker/master/devboxes/login.sh
sed -i "s/EFS_ID/$EFS_ID/g" /etc/pam_scripts/login-logger.sh

sudo chmod 755 /etc/pam_scripts
sudo chown root:root -R /etc/pam_scripts
sudo chmod ugo+x /etc/pam_scripts/login-logger.sh

sudo grep -qxF "session optional pam_exec.so seteuid /etc/pam_scripts/login-logger.sh" /etc/pam.d/sshd || echo "session optional pam_exec.so seteuid /etc/pam_scripts/login-logger.sh" >> /etc/pam.d/sshd


# join to domain
sudo install -d --mode=700 --owner=sssd --group=root /etc/sssd/ldap
GOOGLE_LDAP_CRT=$(aws ssm get-parameter --name GOOGLE_LDAP_CRT --with-decryption --region us-east-1 | jq -r .Parameter.Value)
GOOGLE_LDAP_KEY=$(aws ssm get-parameter --name GOOGLE_LDAP_KEY --with-decryption --region us-east-1 | jq -r .Parameter.Value) 
echo -e "${GOOGLE_LDAP_CRT}" >> /etc/sssd/ldap/google.crt
echo -e "${GOOGLE_LDAP_KEY}" >> /etc/sssd/ldap/google.key
sudo chmod 600 /etc/sssd/ldap/google.crt
sudo chmod 600 /etc/sssd/ldap/google.key

wget -O  /etc/sssd/sssd.conf https://raw.githubusercontent.com/wobeng/docker/master/devboxes/sssd.conf 
sed -i "s/SSSD_DOMAINS/$SSSD_DOMAINS/g" /etc/sssd/sssd.conf
sed -i "s/SSSD_DOMAIN1/$SSSD_DOMAIN1/g" /etc/sssd/sssd.conf
sed -i "s/SSSD_SEARCH_BASE1/$SSSD_SEARCH_BASE1/g" /etc/sssd/sssd.conf
sed -i "s/SSSD_DOMAIN2/$SSSD_DOMAIN2/g" /etc/sssd/sssd.conf
sed -i "s/SSSD_SEARCH_BASE2/$SSSD_SEARCH_BASE2/g" /etc/sssd/sssd.conf

sudo authconfig --enablesssd --enablesssdauth --enablemkhomedir --updateall

sudo grep -qxF "sudoers:    files sss" /etc/nsswitch.conf || echo "sudoers:    files sss" >> /etc/nsswitch.conf

sudo chmod 600 /etc/sssd/sssd.conf
sudo chown 0:0 /etc/sssd/sssd.conf /etc/sssd/ldap/*
sudo chmod 600 /etc/sssd/sssd.conf /etc/sssd/ldap/*
sudo restorecon -FRv /etc/sssd

sudo sed -i 's/PasswordAuthentication no/PasswordAuthentication yes/g' /etc/ssh/sshd_config

sudo systemctl enable sssd
sudo systemctl restart sssd
sudo systemctl restart sshd
