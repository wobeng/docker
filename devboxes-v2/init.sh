#!/bin/bash
set -e

# update the system and install packages
sudo dnf update -y 
sudo dnf install -y rsync gettext jq amazon-efs-utils git zip unzip
sudo dnf install -y make glibc-devel gcc patch gcc-c++


# install cronie
sudo dnf install cronie -y
sudo systemctl enable crond
sudo systemctl start crond
sudo systemctl status crond

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


# Set up Python 3.11
sudo dnf install python3.11 -y
sudo python3.11 -m ensurepip
sudo python3.11 -m pip install botocore

# install certbot
sudo dnf install -y augeas-libs
sudo python3.11 -m venv /opt/certbot/
sudo /opt/certbot/bin/pip install --upgrade pip
sudo /opt/certbot/bin/pip install certbot certbot-nginx certbot-dns-route53
sudo ln -sf /opt/certbot/bin/certbot /usr/bin/certbot


# install webserver
sudo dnf install nginx -y
sudo dnf install php php-cli php-mysqlnd php-pdo php-common php-fpm -y
sudo dnf install php-gd php-mbstring php-xml php-dom php-intl php-simplexml -y
sudo systemctl restart nginx
sudo systemctl enable nginx
sudo systemctl start php-fpm
sudo systemctl enable php-fpm


# Install terraform
sudo dnf install -y yum-utils
sudo dnf config-manager --add-repo https://rpm.releases.hashicorp.com/AmazonLinux/hashicorp.repo
sudo dnf -y install terraform

# set up golang
sudo dnf install golang -y

# Install docker
sudo dnf install docker -y
sudo systemctl restart docker
sudo systemctl enable docker
sudo usermod -aG docker ec2-user  


# set up node
curl -fsSL https://rpm.nodesource.com/setup_18.x | sudo bash -
sudo dnf install -y nodejs
node --version
npm --version
sudo npm install -g npm@latest
npm config set strict-ssl false
sudo npm install -g @angular/cli > /dev/null
sudo npm install -g nx@latest > /dev/null
sudo npm install -g angular-gettext-cli
sudo npm install -g @vendure/ngx-translate-extract @angular/compiler typescript tslib@^1.10.0 braces --save-dev


# update  region on efs
sudo sed -i 's/#region = us-east-1/region = us-east-1/g' /etc/amazon/efs/efs-utils.conf

# add user script
sudo mkdir -p /etc/pam_scripts/users
sudo mkdir -p /var/log/exported
sudo chmod 777 /var/log/exported

rm -rf /tmp/docker-master
curl -L "https://github.com/wobeng/docker/archive/refs/heads/master.zip" -o "/tmp/master.zip"
unzip /tmp/master.zip -d /tmp

sudo mv /tmp/docker-master/devboxes-v2/bash_scripts/auth_keys.sh /etc/pam_scripts/auth_keys.sh
sudo mv /tmp/docker-master/devboxes-v2/bash_scripts/users.sh /etc/pam_scripts/users.sh
sudo mv /tmp/docker-master/devboxes-v2/bash_scripts/assign_ports.sh /etc/pam_scripts/assign_ports.sh

sudo mv /tmp/docker-master/devboxes-v2/user_scripts/devbox.sh /usr/local/bin/devbox
sudo mv /tmp/docker-master/devboxes-v2/user_scripts/setup.sh /usr/local/bin/setup.sh
sudo mv /tmp/docker-master/devboxes-v2/user_scripts/sso.sh /usr/local/bin/sso.sh

TOKEN=`curl -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600" -s`
INSTANCE_ID=`curl -H "X-aws-ec2-metadata-token: $TOKEN" -s "http://169.254.169.254/latest/meta-data/instance-id"`
AVAILABILITY_ZONE=`curl -H "X-aws-ec2-metadata-token: $TOKEN" -s "http://169.254.169.254/latest/meta-data/placement/availability-zone"`
REGION="${AVAILABILITY_ZONE%?}"
INSTANCE_NAME="`aws ec2 describe-tags --filters "Name=resource-id,Values=$INSTANCE_ID" "Name=key,Values=Name" --region $REGION --output=text | cut -f5`"
INSTANCE_DOMAIN="`aws ec2 describe-tags --filters "Name=resource-id,Values=$INSTANCE_ID" "Name=key,Values=Domain" --region $REGION --output=text | cut -f5`"
ALLOWED_DOMAINS="`aws ec2 describe-tags --filters "Name=resource-id,Values=$INSTANCE_ID" "Name=key,Values=Domains" --region $REGION --output=text | cut -f5`"

sudo sed -i "s/DOMAINS/$ALLOWED_DOMAINS/g" /etc/pam_scripts/users.sh
sudo sed -i "s/INSTANCE_NAME/$INSTANCE_NAME/g" /etc/pam_scripts/users.sh
sudo sed -i "s/INSTANCE_DOMAIN/$INSTANCE_DOMAIN/g" /etc/pam_scripts/users.sh

sudo chmod 700 /etc/pam_scripts
sudo chown root:root -R /etc/pam_scripts
sudo chown ec2-user:ec2-user /etc/pam_scripts/users.sh
sudo chown ec2-user:ec2-user /etc/pam_scripts/assign_ports.sh
sudo chmod ugo+x -R /etc/pam_scripts

sudo chmod ugo+x /usr/local/bin/devbox
sudo chmod ugo+x /usr/local/bin/sso.sh
sudo chmod ugo+x /usr/local/bin/setup.sh

# increase watchers
sudo echo "fs.inotify.max_user_watches=524288" >> /etc/sysctl.conf
sudo echo "net.ipv4.ip_nonlocal_bind = 1" >> /etc/sysctl.conf
sudo /usr/sbin/sysctl -p

# install ssl
sudo certbot certonly -i nginx --dns-route53 --no-redirect -d "${INSTANCE_NAME}.${INSTANCE_DOMAIN}" -d "*.${INSTANCE_NAME}.${INSTANCE_DOMAIN}" --non-interactive --agree-tos --register-unsafely-without-email --expand

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

# add cron scripts
touch /var/spool/cron/root
/usr/bin/crontab /var/spool/cron/root
echo "*/5 * * * * cd /root && /bin/bash -c '/etc/pam_scripts/users.sh' >> /var/log/create-users.log 2>&1" >> /var/spool/cron/root
echo "0 0 * * 0 cd /root && sudo certbot renew -i nginx --dns-route53 --no-redirect --non-interactive --agree-tos --register-unsafely-without-email --expand" >> /var/spool/cron/root

#reload nginx
sudo systemctl reload nginx

# change over iam role from devboxes-admin to devboxes
sudo mkdir ~/.aws && chmod 700 ~/.aws
sudo touch ~/.aws/credentials
aws iam create-user --user-name $INSTANCE_ID
aws iam add-user-to-group --user-name $INSTANCE_ID --group-name devboxes-admin
keys=$(aws iam create-access-key --user-name $INSTANCE_ID)
aid=$(aws ec2 describe-iam-instance-profile-associations  --region us-east-1 --filters Name=instance-id,Values=$INSTANCE_ID | jq --raw-output  .IamInstanceProfileAssociations[0].AssociationId)
aws ec2 replace-iam-instance-profile-association --iam-instance-profile Name=devboxes --association-id $aid
echo "[default]" >> ~/.aws/credentials
echo "aws_access_key_id=$(echo $keys | jq --raw-output .AccessKey.AccessKeyId)" >> ~/.aws/credentials
echo "aws_secret_access_key=$(echo $keys | jq --raw-output .AccessKey.SecretAccessKey)" >> ~/.aws/credentials
chmod 600  ~/.aws/credentials

sudo sed -i 's/#Port 22/Port 55977/g' /etc/ssh/sshd_config
sudo sed -i 's/#UseDNS yes/UseDNS no/g' /etc/ssh/sshd_config
sudo sed -i 's/GSSAPIAuthentication yes/GSSAPIAuthentication no/g' /etc/ssh/sshd_config
sudo sed -i 's/ClientAliveInterval 0/ClientAliveInterval 300/g' /etc/ssh/sshd_config
sudo sed -i 's,AuthorizedKeysCommandUser ec2-instance-connect,AuthorizedKeysCommandUser root,g' /etc/ssh/sshd_config
sudo sed -i 's,AuthorizedKeysCommand /opt/aws/bin/eic_run_authorized_keys %u %f,AuthorizedKeysCommand /bin/sh /etc/pam_scripts/auth_keys.sh %u %f %h,g' /etc/ssh/sshd_config
sudo systemctl restart sshd
