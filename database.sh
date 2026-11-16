#!/bin/bash

user_id=$(id -u)
logs_folder="/var/log/expense"
script_name="database"
logs_file="${logs_folder}/${script_name}.log"
domain_name="$DOMAIN_NAME"
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

dnf install mysql-server -y &>> $logs_file
validate $? "Installing mysql-server"

systemctl enable mysqld &>> $logs_file
systemctl start mysqld &>> $logs_file
validate $? "Starting mysql-server"

# mysql_secure_installation --set-root-pass ExpenseApp@1

# Set root password if not already set, and allow remote root connection from backend
mysql -h localhost -u root -pExpenseApp@1 -e "SHOW DATABASES;" &>> $logs_file
if [ $? -ne 0 ]; then
    mysql -e "ALTER USER 'root'@'localhost' IDENTIFIED WITH mysql_native_password BY 'ExpenseApp@1';" &>> $logs_file
fi
# Allow remote connections for root (needed for backend schema load)
mysql -u root -pExpenseApp@1 -e "CREATE USER IF NOT EXISTS 'root'@'%' IDENTIFIED BY 'ExpenseApp@1'; GRANT ALL PRIVILEGES ON *.* TO 'root'@'%' WITH GRANT OPTION; FLUSH PRIVILEGES;" &>> $logs_file
validate $? "Configuring MySQL root user and remote access"

echo "$(timestamp) [INFO] Script completed in $SECONDS seconds"
echo "$(timestamp) [INFO] ==== Script completed Execution =====" | tee -a $logs_file