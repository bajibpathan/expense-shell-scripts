#!/bin/bash

USERID=$(id -u)
RED="\e[31m"
GREEN="\e[32m"
YELLOW="\e[33m"
DEFAULT="\e[0m"
LOGS_FOLDER="/var/log/roboshop-logs"
SCRIPT_NAME=$(echo $0 | cut -d "." -f1)
LOG_FILE="$LOGS_FOLDER/$SCRIPT_NAME.log"
SCRIPT_DIR=$PWD

# Create log folder
mkdir -p $LOGS_FOLDER

# Check if the user has proper privileges to run the script
if [ $USERID -ne 0 ]
then
    echo -e "$RED ERROR:: Please run this script with root access $DEFAULT" | tee -a $LOG_FILE
    exit 1
else
    echo "You are running with root access"  | tee -a $LOG_FILE
fi

## Functions
VALIDATE(){
    if [ $? -eq 0 ]
    then
        echo -e "$2 is ... $GREEN SUCCESS $NOCOLOR"  | tee -a $LOG_FILE
    else
        echo -e "$2 is ...$RED FAILURE $NOCOLOR"  | tee -a $LOG_FILE
        exit 1
    fi
}

echo "Script started executing: $(date)" | tee -a $LOG_FILE


dnf install nginx -y &>>$LOG_FILE
VALIDATE $? "Installing Nginx"

systemctl enable nginx &>>$LOG_FILE
VALIDATE $? "Enabling nginx service at the start up"

systemctl start nginx &>>$LOG_FILE
VALIDATE $? "Starting nginx service"

rm -rf /usr/share/nginx/html/*
VALIDTE $? "Removing default content"

curl -o /tmp/frontend.zip https://expense-builds.s3.us-east-1.amazonaws.com/expense-frontend-v2.zip &>>$LOG_FILE
VALIDATE $? "Downloading the content"

cd /usr/share/nginx/html 
unzip /tmp/frontend.zip &>>$LOG_FILE
VALIDATE $? "Unzipping the frontend content"

cp $SCRIPT_DIR/conf/expense.conf /etc/nginx/default.d/expense.conf
VALIDATE $? "Copying expense configuration"

systemctl restart nginx &>>$LOG_FILE
VALIDATE $? "Restarting the nginx service"