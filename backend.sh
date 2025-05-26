#!/bin/bash

START_TIME=$(date +%s)
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

echo "Enter root password"
read -s MYSQL_ROOT_PASSWORD

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

dnf module disable nodejs -y
VALIDATE $? "Disabling NodeJS default module"

dnf module enable nodejs:20 -y
VALIDATE $? "Enabling NodeJS 20 module"

dnf install nodejs -y
VALIDATE $? "Installing NodeJS"

id expense &>>$LOG_FILE
if [ $? -ne 0 ]
then
    useradd --system --home /app --shell /sbin/nologin --comment "expense user" expense &>>$LOG_FILE
    VALIDATE $? "Creating a expense system user"
else
    echo -e "System user expense already created ... $YELLOW SKIPPING $DEFAULT" 
fi

mkdir -p /app
VALIDATE $? "Creating /app directory"

curl -o /tmp/backend.zip https://expense-builds.s3.us-east-1.amazonaws.com/expense-backend-v2.zip &>>$LOG_FILE
VALIDATE $? "Downloading backend code to temp directory"

rm -rf /app/*
cd /app 
unzip /tmp/backend.zip &>>$LOG_FILE
VALIDATE $? "Extracting the backend code to /app directory"

npm install &>>$LOG_FILE
VALIDATE $? "Installing dependencies"

cp $SCRIPT_DIR/services/backend.service /etc/systemd/system/backend.service
VALIDATE $? "Copying backend serivce to systemd directory"

systemctl daemon-reload &>>$LOG_FILE
VALIDATE $? "Reloading systemd daemon"

systemctl enable backend &>>$LOG_FILE
VALIDATE $? "Enabling backend service"

systemctl start backend &>>$LOG_FILE
VALIDATE $? "Starting backend service"

dnf install mysql -y &>>$LOG_FILE
VALIDATE $? "Installing MySQL client"

mysql -h mysql.robodevops.store -uroot -p$MYSQL_ROOT_PASSWORD < /app/schema/backend.sql &>>$LOG_FILE
VALIDATE $? "Loading tranactions schema"

systemctl restart backend &>>$LOG_FILE
VALIDATE $? "Restarting backend service"

END_TIME=$(date +%s)
TOTAL_TIME=$(( $END_TIME - $START_TIME))
echo -e "Script execution completed successfully, $YELLOW time taken: $TOTAL_TIME seconds $DEFAULT" | tee -a $LOG_FILE