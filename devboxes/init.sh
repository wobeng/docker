#!/bin/bash

set -e

# update the system and install packages
sudo yum remove -y awscli
sudo yum update -y && sudo yum install -y rsync gettext jq amazon-efs-utils git zip unzip sssd sssd-tools sssd-ldap openldap-clients rsync

# start ssm
sudo systemctl restart amazon-ssm-agent
sudo systemctl enable amazon-ssm-agent

# install lamp
sudo yum install -y httpd
sudo amazon-linux-extras install php7.2 -y
sudo systemctl restart httpd
sudo systemctl enable httpd

# install terraform
sudo yum install -y yum-utils
sudo yum-config-manager --add-repo https://rpm.releases.hashicorp.com/AmazonLinux/hashicorp.repo
sudo yum -y install terraform

# Install docker
sudo amazon-linux-extras install docker -y
sudo systemctl restart docker
sudo systemctl enable docker
sudo usermod -aG docker ec2-user  

# set up python
python3  --version
python3 -m pip install botocore
python3 -m pip uninstall awscli

# set up node
curl -sL https://rpm.nodesource.com/setup_14.x | sudo bash -
sudo yum install -y nodejs
node --version
npm config set strict-ssl false
npm config set unsafe-perm=true
sudo npm install -g @angular/cli > /dev/null
sudo npm install -g angular-gettext-cli
sudo npm install -g @bartholomej/ngx-translate-extract @angular/compiler typescript tslib@^1.10.0 braces --save-dev

# set aws cli
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip -o awscliv2.zip
sudo ./aws/install --bin-dir /usr/local/bin --install-dir /usr/local/aws-cli --update

# mount efs root
if ! grep -qxF "$EFS_ID:/ /efs efs _netdev,noresvport,tls,iam 0 0" /etc/fstab
then

    sudo mkdir -p /efs/home
    mount -t efs -o tls,iam "$EFS_ID":/ /efs
    echo "$EFS_ID:/ /efs efs _netdev,noresvport,tls,iam 0 0" >> /etc/fstab
    
fi

#ensure all ssh keys are the same
sudo rsync -a --ignore-times  --include='ssh_host_*'  --exclude='*' /efs/host_ssh_keys/ /etc/ssh/

# mount efs workspaces
if ! grep -qxF "$EFS_ID:/workspaces /workspaces efs _netdev,noresvport,tls,iam 0 0" /etc/fstab
then

    sudo mkdir -p /efs/workspaces
    sudo mkdir -p /workspaces
    chmod 700 /workspaces
    mount -t efs -o tls,iam "$EFS_ID":/workspaces /workspaces
    echo "$EFS_ID:/workspaces /workspaces efs _netdev,noresvport,tls,iam 0 0" >> /etc/fstab
fi
 

# add user script
sudo mkdir -p /etc/pam_scripts
sudo mkdir -p /var/log/exported
chmod 777 /var/log/exported

rm -rf /tmp/docker-master
curl -L "https://github.com/wobeng/docker/archive/refs/heads/master.zip" -o "/tmp/master.zip"
unzip /tmp/master.zip -d /tmp

mv /tmp/docker-master/devboxes/bash_scripts/login.sh /etc/pam_scripts/login-logger.sh
mv /tmp/docker-master/devboxes/bash_scripts/auth_keys.sh /etc/pam_scripts/auth_keys.sh

mv /tmp/docker-master/devboxes/user_scripts/devbox.sh /usr/local/bin/devbox
mv /tmp/docker-master/devboxes/user_scripts/setup.sh /usr/local/bin/setup.sh
mv /tmp/docker-master/devboxes/user_scripts/sso.sh /usr/local/bin/sso.sh
mv /tmp/docker-master/devboxes/user_scripts/startup.sh /usr/local/bin/workspace-one-time-startup.sh

sed -i "s/EFS_ID/$EFS_ID/g" /etc/pam_scripts/login-logger.sh

sudo chmod 755 /etc/pam_scripts
sudo chown root:root -R /etc/pam_scripts
sudo chmod ugo+x -R /etc/pam_scripts

sudo chmod ugo+x /usr/local/bin/devbox
sudo chmod ugo+x /usr/local/bin/sso.sh
sudo chmod ugo+x /usr/local/bin/setup.sh
sudo chmod ugo+x /usr/local/bin/workspace-one-time-startup.sh

sudo grep -qxF "session optional pam_exec.so seteuid /etc/pam_scripts/login-logger.sh" /etc/pam.d/sshd || echo "session optional pam_exec.so seteuid /etc/pam_scripts/login-logger.sh" >> /etc/pam.d/sshd


# join to domain
sudo install -d --mode=700 --owner=sssd --group=root /etc/sssd/ldap
GOOGLE_LDAP_CRT=$(/usr/local/bin/aws ssm get-parameter --name GOOGLE_LDAP_CRT --with-decryption --region us-east-1 | jq -r .Parameter.Value)
GOOGLE_LDAP_KEY=$(/usr/local/bin/aws ssm get-parameter --name GOOGLE_LDAP_KEY --with-decryption --region us-east-1 | jq -r .Parameter.Value) 
echo -e "${GOOGLE_LDAP_CRT}" >> /etc/sssd/ldap/google.crt
echo -e "${GOOGLE_LDAP_KEY}" >> /etc/sssd/ldap/google.key
sudo chmod 600 /etc/sssd/ldap/google.crt
sudo chmod 600 /etc/sssd/ldap/google.key

mv /tmp/docker-master/devboxes/sssd.conf  /etc/sssd/sssd.conf
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

sudo sed -i 's/#Port 22/Port 55977/g' /etc/ssh/sshd_config
sudo sed -i 's/PasswordAuthentication no/PasswordAuthentication yes/g' /etc/ssh/sshd_config
sudo sed -i 's,AuthorizedKeysCommandUser ec2-instance-connect,AuthorizedKeysCommandUser root,g' /etc/ssh/sshd_config
sudo sed -i 's,AuthorizedKeysCommand /opt/aws/bin/eic_run_authorized_keys %u %f,AuthorizedKeysCommand /bin/sh /etc/pam_scripts/auth_keys.sh %u %f %h,g' /etc/ssh/sshd_config

sudo systemctl enable sssd
sudo systemctl restart sssd
sudo systemctl restart sshd
