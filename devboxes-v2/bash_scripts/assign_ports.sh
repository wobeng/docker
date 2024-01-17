#!/bin/bash

IP=0.0.0.0

first_port=60000
last_port=65535
loginUsername="$1"
homeDir="$2"
hostName="$3"

portsDir="/data/ports"
usersPortsDir="$portsDir/users"
portsPortsDir="$portsDir/ports"
userPorts="$usersPortsDir/${loginUsername}.txt"

if [ -f "$userPorts" ]; then
     echo "$userPorts already exist. Exiting...."
     exit 1
fi


function freeport {
    for ((port=$first_port; port<=$last_port; port++))
        do
            # continue if port exist 
            if [[ -f "$portsPortsDir/$port" ]]; then
                continue
            fi
            
            # continue if port is not free
            (/usr/bin/echo >/dev/tcp/$IP/$port) > /dev/null 2>&1 && continue 

            echo $port
            break
        done
}


# reserve ports
for run in {1..6}; do
    # get and reserve ips
    inport=$(freeport)
    /usr/bin/echo "$loginUsername" >>  "$portsPortsDir/$inport"
    outport=$(freeport)
    /usr/bin/echo "$loginUsername" >>  "$portsPortsDir/$outport"
    /usr/bin/echo "${inport}_${outport}" >>  "$userPorts"

    # expose the port as env
    /usr/bin/echo "export USER_INPORT${run}=$inport" >> "$homeDir/.bashrc"
    /usr/bin/echo "export USER_OUTPORT${run}=$outport" >> "$homeDir/.bashrc"

    # create nginx conf
    cat << EOF >> "/etc/nginx/conf.d/${loginUsername}.conf"
server {
listen $outport ssl; 
server_name $hostName;
server_name *.$hostName;
location / {
    proxy_set_header Host \$http_host;
    proxy_set_header X-Real-IP \$remote_addr;
    proxy_set_header Cross-Origin-Embedder-Policy require-corp;
    proxy_set_header Cross-Origin-Opener-Policy same-origin;
    proxy_pass http://localhost:$inport;
}
ssl_certificate /etc/letsencrypt/live/$hostName/fullchain.pem; # managed by Certbot
ssl_certificate_key /etc/letsencrypt/live/$hostName/privkey.pem; # managed by Certbot
include /etc/letsencrypt/options-ssl-nginx.conf; # managed by Certbot
ssl_dhparam /etc/letsencrypt/ssl-dhparams.pem; # managed by Certbot
}
EOF
     /usr/bin/echo "" >> "/etc/nginx/conf.d/${loginUsername}.conf"
done
