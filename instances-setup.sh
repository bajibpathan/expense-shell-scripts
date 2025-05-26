#!/bin/bash

START_TIME=$(date +%s)
USER_ID=$(id -u)
AMI_ID="ami-09c813fb71547fc4f"
SG_ID="sg-0d72167c5d5dfcb1b"
INSTANCES="$@"
ZONE_ID="Z04638081NLZ031HSLG68"
DOMAIN_NAME="robodevops.store"
LOG_FOLDER="/var/log/expense-app-logs"
SCRIPT_NAME=$(echo $0 | cut -d "." -f1)
LOG_FILE="${LOG_FOLDER}/${SCRIPT_NAME}.log"

# Colors
RED="\e[31m"
GREEN="\e[32m"
YELLOW="\e[33m"
DEFAULT="\e[0m"



if [ "$#" -lt 1 ]; then
    echo -e "$YELLOW Please pass the components as arguments $DEFAULT"
    echo -e "$RED USAGE:: $DEFAULT $0 [compoents]"
    exit 1
fi

mkdir -p $LOG_FOLDER
echo "Script started executing: $(date)" | tee -a $LOG_FILE

if [ $USER_ID -ne 0 ]
then
    echo -e "$RED ERROR:: Please run this script with root access $NOCOLOR" | tee -a $LOG_FILE
    exit 1
else
    echo "You are running with root access"  | tee -a $LOG_FILE
fi

# To verify if aws cli is installed
aws --version &> /dev/null
if [ $? -ne 0 ]; then
    echo -e "$YELLOW AWS CLI is NOT installed $DEFAULT"
    echo -e "$Green Installing AWS CLI $DEFAULT"
    dnf install awscli -y &>>$LOG_FILE
    echo -e "AWS CLI installed $GREEN successfully $DEFAULT"
else
    echo -e "AWS CLI is $YELLOW already $DEFAULT installed"
fi

# To verify if we are able to connect to CLI
aws s3 ls &> /dev/null
if [ $? -ne 0 ]
then
    echo -e  "$RED ERROR:: Please verify aws access keys configuration(/root/.aws/config) $DEFAULT"
else
    echo -e "$GREEN Connected to AWS..Instances creation is started. $DEFAULT"

    for instance in ${INSTANCES[@]}
    do
        
        # create Instance
        INSTANCE_ID=$(aws ec2 run-instances \
        --image-id $AMI_ID \
        --instance-type t2.micro \
        --security-group-ids $SG_ID \
        --tag-specifications "ResourceType=instance,Tags=[{Key=Name, Value=$instance}]" \
        --query "Instances[0].InstanceId" \
        --output text)

        # obtain IP address of the instance
        if [ $instance != "frontend" ]
        then
            IP=$(aws ec2 describe-instances \
            --instance-ids $INSTANCE_ID \
            --query "Reservations[0].Instances[0].PrivateIpAddress" \
            --output text)
            RECORD_NAME="$instance.$DOMAIN_NAME"
        else
            IP=$(aws ec2 describe-instances \
            --instance-ids $INSTANCE_ID \
            --query "Reservations[0].Instances[0].PublicIpAddress" \
            --output text)
            RECORD_NAME="$DOMAIN_NAME"
        fi

        echo "$instance IP address: $IP"
        echo "Record Name: $RECORD_NAME"

        # update the Domian Records
        aws route53 change-resource-record-sets \
        --hosted-zone-id $ZONE_ID \
        --change-batch '
        {
            "Comment": "Creating or Updating a record set for the $instance"
            ,"Changes": [{
            "Action"              : "UPSERT"
            ,"ResourceRecordSet"  : {
                "Name"              : "'$RECORD_NAME'"
                ,"Type"             : "A"
                ,"TTL"              : 1
                ,"ResourceRecords"  : [{
                    "Value"         : "'$IP'"
                }]
            }
            }]
        }'
    done
fi