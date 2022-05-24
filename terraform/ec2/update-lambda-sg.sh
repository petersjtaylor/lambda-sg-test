#!/usr/bin/env bash

# we get the default group for the given vpc
VPC_ID=$1

# source security group that we will remove from enis
SOURCE_SG_ID=$2

TARGET_SG_ID=$(aws ec2 describe-security-groups \
    --filters Name=description,Values='default VPC security group' \
    Name=vpc-id,Values=${VPC_ID} \
    --output text \
    --query 'SecurityGroups[0].GroupId')

# Get ENI's from source SG
enis=$(aws ec2 describe-network-interfaces \
	   --filters Name=group-id,Values=${SOURCE_SG_ID} Name=interface-type,Values=lambda \
	   --output text \
	   --query 'NetworkInterfaces[*].NetworkInterfaceId')

# Assign eni's to temporary SG
for item in ${enis}; do
  aws ec2 modify-network-interface-attribute --network-interface-id ${item} --groups ${TARGET_SG_ID}
done

echo detached ${enis} from ${SOURCE_SG_ID} and attached to ${TARGET_SG_ID}
