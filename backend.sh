#!/bin/bash

user_id=$(id -u)
logs_folder="/var/log/expense"
script_name="backend"
logs_file="${logs_folder}/${script_name}.log"
domain_name="chinna.online"
# SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
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


dnf module disable nodejs -y &>> $logs_file
dnf module enable nodejs:24 -y &>> $logs_file
dnf install nodejs -y &>> $logs_file
validate $? "Installing nodejs"

# rm -rf /app
# validate $? "Removing old code"

mkdir -p /app
validate $? "Creating app directory"

id expense &>> $logs_file
if [ $? -ne 0 ]; then
    useradd --system --home /app --shell /sbin/nologin --comment "expense system user" expense &>> $logs_file
    validate $? "Creating system user"
else
    echo -e "$(timestamp) [INFO] System user expense already exist...${Y}SKIPPING${N}"
fi

curl -o /tmp/backend.tar.gz https://raw.githubusercontent.com/daws-92s/expense-documentation/refs/heads/main/artifacts/expense-backend-v5.tar.gz
validate $? "Downloading backend artifacts"

cd /app
tar -xzf /tmp/backend.tar.gz &>> $logs_file
validate $? "Extracting backend artifacts"

npm install &>> $logs_file
validate $? "Installing backend dependencies"


# sed -i "s/DOMAIN_NAME/$domain_name/g" "$SCRIPT_DIR/backend.service"
# cp "$SCRIPT_DIR/backend.service" /etc/systemd/system/backend.service

cat <<EOF > /etc/systemd/system/backend.service
[Unit]
Description=Expense Backend Service
After=network.target

[Service]
User=expense
Environment=DB_HOST=database.${domain_name}
Environment=DB_USER=expense
Environment=DB_PWD=ExpenseApp@1
Environment=DB_DATABASE=transactions
Environment=ADMIN_TOKEN=admin123
ExecStart=/bin/node /app/index.js
SyslogIdentifier=backend
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF
validate $? "Creating backend systemd service"

dnf install mysql -y &>> $logs_file
validate $? "Installing mysql client"

# Wait until database.chinna.online is reachable before loading schema
until mysql -h "database.$domain_name" -u root -pExpenseApp@1 -e "SELECT 1;" &>> $logs_file; do
    echo "$(timestamp) [INFO] Waiting for MySQL database to be ready..." | tee -a $logs_file
    sleep 10
done

mysql -h "database.$domain_name" -u root -pExpenseApp@1 < /app/schema/backend.sql &>> $logs_file
validate $? "Creating backend database"

systemctl daemon-reload &>> $logs_file
systemctl enable backend &>> $logs_file
systemctl start backend &>> $logs_file
validate $? "Starting backend service"


echo "$(timestamp) [INFO] Script completed in $SECONDS seconds"
echo "$(timestamp) [INFO] ==== Script completed Execution =====" | tee -a $logs_file