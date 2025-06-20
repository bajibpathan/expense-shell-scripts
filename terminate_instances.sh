#!/bin/bash

AMI_ID="ami-09c813fb71547fc4f"
SG_ID="sg-0d72167c5d5dfcb1b"
INSTANCES="$@"
ZONE_ID="Z04638081NLZ031HSLG68"
DOMAIN_NAME="robodevops.store"
RED="\e[31m"
GREEN="\e[32m"
YELLOW="\e[33m"
DEFAULT="\e[0m"


# To verify if we are able to connect to CLI
aws s3 ls &> /dev/null

if [ $? -ne 0 ]
then
    echo -e  "$RED ERROR:: Please verify aws access keys configuration $DEFAULT"
else
    echo -e "$GREEN Connected to AWS..Instances creation is started. $DEFAULT"

    for instance in ${INSTANCES[@]}
    do
        # Obtaining Instance ID
        INSTANCE_ID=$(aws ec2 describe-instances \
            --filters "Name=tag:Name,Values=$instance" \
            --query "Reservations[].Instances[].InstanceId" \
            --output text)

        echo -e "$YELLOW Terminating the $instance $DEFAULT"
        aws ec2 terminate-instances --instance-ids $INSTANCE_ID &> /dev/null
        echo -e "$instance termiation completed ... $GREEN SUCCESSFULLY $DEFAULT"
    done
fi