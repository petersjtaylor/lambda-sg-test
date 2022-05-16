#!/usr/bin/env bash

# we get the default group for the given vpc
VPC_ID=$1

# source security group that we will remove from enis
SOURCE_SG_ID=$2

# create Temporary SG
tempSG=$(aws ec2 create-security-group --description "Temp SG" --group-name "Temp-SG" | jq -r '.GroupId')

# Get ENI's from source SG
enis=$(aws ec2 describe-network-interfaces \
	   --filters Name=group-id,Values=${SOURCE_SG_ID} Name=interface-type,Values=lambda \
	   --output text \
	   --query 'NetworkInterfaces[*].NetworkInterfaceId')

# Assign eni's to temporary SG
for item in ${enis}; do
  aws ec2 modify-network-interface-attribute --network-interface-id ${item} --groups ${tempSG}
done

echo detached ${enis} from ${SOURCE_SG_ID} to ${tempSG}

# Delete Temporary SG
echo "Deleting temporary SG ${tempSG}"

aws ec2 delete-security-group --group-id ${tempSG}
