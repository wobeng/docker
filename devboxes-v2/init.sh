#!/bin/bash

set -e

# update the system and install packages
sudo yum remove -y awscli
sudo yum update -y && sudo yum install -y rsync gettext jq amazon-efs-utils git zip unzip
sudo amazon-linux-extras install epel -y

# mount ebs
sudo mkfs -t ext4 /dev/sdb
sudo mkdir /data
sudo mount /dev/sdb /data/
sudo mkdir -p /data/home
sudo mkdir -p /data/workspace
sudo mkdir -p /data/ports/ports
sudo mkdir -p /data/ports/users
echo "/dev/sdb       /data   ext4    defaults,nofail        0       0" >> /etc/fstab
sudo mount -a

# start ssm
sudo systemctl restart amazon-ssm-agent
sudo systemctl enable amazon-ssm-agent

# install webserver
sudo amazon-linux-extras install nginx1 -y
sudo amazon-linux-extras enable php8.0 -y
sudo yum install php php-cli php-mysqlnd php-pdo php-common php-fpm -y
sudo yum install php-gd php-mbstring php-xml php-dom php-intl php-simplexml -y
sudo yum install -y certbot python2-certbot-nginx
sudo yum install -y python2-certbot-dns-route53
sudo systemctl restart nginx
sudo systemctl enable nginx
sudo systemctl start php-fpm
sudo systemctl enable php-fpm

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
mv /tmp/docker-master/devboxes-v2/bash_scripts/assign_ports.sh /etc/pam_scripts/assign_ports.sh

mv /tmp/docker-master/devboxes-v2/user_scripts/devbox.sh /usr/local/bin/devbox
mv /tmp/docker-master/devboxes-v2/user_scripts/setup.sh /usr/local/bin/setup.sh
mv /tmp/docker-master/devboxes-v2/user_scripts/sso.sh /usr/local/bin/sso.sh

INSTANCE_ID="`wget -qO- http://instance-data/latest/meta-data/instance-id`"
REGION="`wget -qO- http://instance-data/latest/meta-data/placement/availability-zone | sed -e 's:\([0-9][0-9]*\)[a-z]*\$:\\1:'`"
INSTANCE_NAME="`/usr/local/bin/aws ec2 describe-tags --filters "Name=resource-id,Values=$INSTANCE_ID" "Name=key,Values=Name" --region $REGION --output=text | cut -f5`"
INSTANCE_DOMAIN="`/usr/local/bin/aws ec2 describe-tags --filters "Name=resource-id,Values=$INSTANCE_ID" "Name=key,Values=Domain" --region $REGION --output=text | cut -f5`"
ALLOWED_DOMAINS="`/usr/local/bin/aws ec2 describe-tags --filters "Name=resource-id,Values=$INSTANCE_ID" "Name=key,Values=Domains" --region $REGION --output=text | cut -f5`"

sed -i "s/DOMAINS/$ALLOWED_DOMAINS/g" /etc/pam_scripts/users.sh
sed -i "s/INSTANCE_NAME/$INSTANCE_NAME/g" /etc/pam_scripts/users.sh
sed -i "s/INSTANCE_DOMAIN/$INSTANCE_DOMAIN/g" /etc/pam_scripts/users.sh

sudo chmod 700 /etc/pam_scripts
sudo chown root:root -R /etc/pam_scripts
sudo chown ec2-user:ec2-user /etc/pam_scripts/users.sh
sudo chown ec2-user:ec2-user /etc/pam_scripts/assign_ports.sh
sudo chmod ugo+x -R /etc/pam_scripts

sudo chmod ugo+x /usr/local/bin/devbox
sudo chmod ugo+x /usr/local/bin/sso.sh
sudo chmod ugo+x /usr/local/bin/setup.sh

# increase watchers
echo "fs.inotify.max_user_watches=524288" >> /etc/sysctl.conf
echo "net.ipv4.ip_nonlocal_bind = 1" >> /etc/sysctl.conf
sudo /usr/sbin/sysctl -p

# install ssl
sudo certbot certonly -i nginx --dns-route53 --no-redirect -d "*.${INSTANCE_NAME}.${INSTANCE_DOMAIN}" -d "${INSTANCE_NAME}.${INSTANCE_DOMAIN}" --non-interactive --agree-tos --register-unsafely-without-email --expand

# change over iam role from devboxes-admin to devboxes
sudo mkdir ~/.aws && chmod 700 ~/.aws
sudo touch ~/.aws/credentials
/usr/local/bin/aws iam create-user --user-name $INSTANCE_NAME || true
/usr/local/bin/aws iam add-user-to-group --user-name $INSTANCE_NAME --group-name devboxes-admin || true
keys=$(/usr/local/bin/aws iam create-access-key --user-name $INSTANCE_NAME)
aid=$(/usr/local/bin/aws ec2 describe-iam-instance-profile-associations  --region us-east-1 --filters Name=instance-id,Values=$INSTANCE_ID | jq --raw-output  .IamInstanceProfileAssociations[0].AssociationId)
/usr/local/bin/aws ec2 replace-iam-instance-profile-association --iam-instance-profile Name=devboxes --association-id $aid
echo "[default]" >> ~/.aws/credentials
echo "aws_access_key_id=$(echo $keys | jq --raw-output .AccessKey.AccessKeyId)" >> ~/.aws/credentials
echo "aws_secret_access_key=$(echo $keys | jq --raw-output .AccessKey.SecretAccessKey)" >> ~/.aws/credentials
chmod 600  ~/.aws/credentials


# create users
sudo /bin/bash -c '/etc/pam_scripts/users.sh' >> /var/log/create-users.log

# add config and restart nginx
hostName="${INSTANCE_NAME}.${INSTANCE_DOMAIN}"
    cat << EOF >> "/etc/nginx/conf.d/main.conf"
server {
listen 80; 
server_name $hostName;
server_name *.$hostName;
location / {
    default_type text/html;
    return 200 "<!DOCTYPE html><h2>Hello World</h2>\n";
}
}
EOF
sudo systemctl reload nginx

# add cron scripts
touch /var/spool/cron/root
/usr/bin/crontab /var/spool/cron/root
echo "*/5 * * * * cd /root && /bin/bash -c '/etc/pam_scripts/users.sh' >> /var/log/create-users.log 2>&1" >> /var/spool/cron/root
echo "0 * * * * cd /root && sudo certbot renew -i nginx --dns-route53 --no-redirect --non-interactive --agree-tos --register-unsafely-without-email --expand" >> /var/spool/cron/root

sudo sed -i 's/#Port 22/Port 55977/g' /etc/ssh/sshd_config
sudo sed -i 's/PasswordAuthentication no/PasswordAuthentication yes/g' /etc/ssh/sshd_config
sudo sed -i 's/ClientAliveInterval 0/ClientAliveInterval 300/g' /etc/ssh/sshd_config
sudo sed -i 's,AuthorizedKeysCommandUser ec2-instance-connect,AuthorizedKeysCommandUser root,g' /etc/ssh/sshd_config
sudo sed -i 's,AuthorizedKeysCommand /opt/aws/bin/eic_run_authorized_keys %u %f,AuthorizedKeysCommand /bin/sh /etc/pam_scripts/auth_keys.sh %u %f %h,g' /etc/ssh/sshd_config
sudo systemctl restart sshd
