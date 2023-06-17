#!/bin/bash

set -e

# update the system and install packages
sudo yum remove -y awscli
sudo yum update -y && sudo yum install -y rsync gettext jq amazon-efs-utils git zip unzip

# mount ebs
sudo mkfs -t ext4 /dev/sdb
sudo mkdir /data
sudo mount /dev/sdb /data/
sudo mkdir -p /data/home
sudo mkdir -p /data/workspace
sudo mkdir -p /data/ports
echo "/dev/sdb       /data   ext4    defaults,nofail        0       0" >> /etc/fstab
sudo mount -a

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

# set up golang
sudo amazon-linux-extras install golang1.19 -y

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
curl -sL https://rpm.nodesource.com/setup_16.x | sudo bash -
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

sudo sed -i 's/#region = us-east-1/region = us-east-1/g' /etc/amazon/efs/efs-utils.conf

# add user script
sudo mkdir -p /etc/pam_scripts/users
sudo mkdir -p /var/log/exported
chmod 777 /var/log/exported

rm -rf /tmp/docker-master
curl -L "https://github.com/wobeng/docker/archive/refs/heads/master.zip" -o "/tmp/master.zip"
unzip /tmp/master.zip -d /tmp

mv /tmp/docker-master/devboxes-v2/bash_scripts/auth_keys.sh /etc/pam_scripts/auth_keys.sh
mv /tmp/docker-master/devboxes-v2/bash_scripts/users.sh /etc/pam_scripts/users.sh

mv /tmp/docker-master/devboxes-v2/user_scripts/devbox.sh /usr/local/bin/devbox
mv /tmp/docker-master/devboxes-v2/user_scripts/setup.sh /usr/local/bin/setup.sh
mv /tmp/docker-master/devboxes-v2/user_scripts/sso.sh /usr/local/bin/sso.sh

sed -i "s/DOMAINS/$DOMAINS/g" /etc/pam_scripts/users.sh

sudo chmod 700 /etc/pam_scripts
sudo chown root:root -R /etc/pam_scripts
sudo chown ec2-user:ec2-user /etc/pam_scripts/users.sh
sudo chmod ugo+x -R /etc/pam_scripts

sudo chmod ugo+x /usr/local/bin/devbox
sudo chmod ugo+x /usr/local/bin/sso.sh
sudo chmod ugo+x /usr/local/bin/setup.sh


# increase watchers
echo "fs.inotify.max_user_watches=524288" >> /etc/sysctl.conf
sudo /usr/sbin/sysctl -p

# create users
sudo /bin/bash -c '/etc/pam_scripts/users.sh' >> /var/log/create-users.log

# add cron scripts
touch /var/spool/cron/root
/usr/bin/crontab /var/spool/cron/root
echo "*/5 * * * * cd /root && /bin/bash -c '/etc/pam_scripts/users.sh' >> /var/log/create-users.log 2>&1" >> /var/spool/cron/root

sudo sed -i 's/#Port 22/Port 55977/g' /etc/ssh/sshd_config
sudo sed -i 's/PasswordAuthentication no/PasswordAuthentication yes/g' /etc/ssh/sshd_config
sudo sed -i 's/ClientAliveInterval 0/ClientAliveInterval 300/g' /etc/ssh/sshd_config
sudo sed -i 's,AuthorizedKeysCommandUser ec2-instance-connect,AuthorizedKeysCommandUser root,g' /etc/ssh/sshd_config
sudo sed -i 's,AuthorizedKeysCommand /opt/aws/bin/eic_run_authorized_keys %u %f,AuthorizedKeysCommand /bin/sh /etc/pam_scripts/auth_keys.sh %u %f %h,g' /etc/ssh/sshd_config
sudo systemctl restart sshd
