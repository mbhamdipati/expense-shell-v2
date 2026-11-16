#!/bin/bash

user_id=$(id -u)
logs_folder="/var/log/expense"
script_name="frontend"
logs_file="${logs_folder}/${script_name}.log"
domain_name="chinna.online"

R="\e[31m"
G="\e[32m"
Y="\e[33m"
N="\e[0m"

timestamp(){
    date "+%F %T"
}

if [ $user_id -ne 0 ]; then
    echo "Please run this script with sudo access..."
    exit 1
fi

mkdir -p $logs_folder
echo "Script execution started at $(date +"%F %T")" &>> $logs_file

validate() {
    if [ $1 -ne 0 ]; then
        echo -e "${2} ${R}failed${N}" | tee -a $logs_file
        exit 1
    else
        echo -e "${2} ${G}successful${N}" | tee -a $logs_file
    fi
}

echo "$(timestamp) [INFO] ==== Script started Execution =====" | tee -a $logs_file

dnf install nginx -y &>> $logs_file
validate $? "Installing nginx"

systemctl enable nginx &>> $logs_file
systemctl start nginx &>> $logs_file
validate $? "Starting nginx"

rm -rf /usr/share/nginx/html/* &>> $logs_file
validate $? "Removing old code"

curl -o /tmp/frontend.tar.gz https://raw.githubusercontent.com/daws-92s/expense-documentation/refs/heads/main/artifacts/expense-frontend-v5.tar.gz &>> $logs_file
validate $? "Downloading frontend artifacts"

cd /usr/share/nginx/html
tar -xzf /tmp/frontend.tar.gz &>> $logs_file
validate $? "Extracting frontend artifacts"

# Write Nginx reverse proxy config directly
cat <<EOF > /etc/nginx/default.d/expense.conf
proxy_http_version 1.1;
proxy_set_header Host              \$host;
proxy_set_header X-Real-IP         \$remote_addr;
proxy_set_header X-Forwarded-For   \$proxy_add_x_forwarded_for;
proxy_set_header X-Forwarded-Proto \$scheme;
proxy_connect_timeout 5s;
proxy_read_timeout    30s;

# Browser calls /api/transaction → nginx strips /api → backend gets /transaction
location /api/ {
    proxy_pass http://backend.${domain_name}:8080/;
}

location /health {
    stub_status on;
    access_log off;
}

location = /home {
    return 301 /;
}

location = /docs {
    return 302 https://developer.mozilla.org/en-US/docs/Web/HTTP/Reference/Status;
}

location /admin {
    deny all;
}
EOF
validate $? "Creating nginx expense.conf"

nginx -t &>> $logs_file
validate $? "Testing nginx configuration"

systemctl restart nginx &>> $logs_file
validate $? "Restarting nginx"

echo "$(timestamp) [INFO] Script completed in $SECONDS seconds"
echo "$(timestamp) [INFO] ==== Script completed Execution =====" | tee -a $logs_file
