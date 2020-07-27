#!/bin/bash

TARGET_INSTANCE=$1
echo "Working on instance: $1"
USERNAME=$2
echo "Insert key for user: $2"
NEW_KEY=$3
echo "keypair $3 will be added to Instance $1"

send_remote_command () {
    ssh -o StrictHostKeyChecking=no -o ConnectTimeout=5 $1 $2
}

read_error () {
    # Reads errors and exits script
    if grep -q $1 $2; then
        echo "Error cought: $1"
        exit 1
    fi
}

if [ -z $AWS_DEFAULT_REGION ]; then
    echo "AWS_DEFAULT_REGION Not passed
Assuming you mean eu-west-1"
    export AWS_DEFAULT_REGION=eu-west-1
fi

# Find your instance
instance_dict=$(aws ec2 describe-instances --instance-ids $TARGET_INSTANCE --query "Reservations[0].Instances[0]")
INSTANCE_FOUND=$?

if [ $INSTANCE_FOUND -eq 0 ]; then
    instance_id=$(echo $instance_dict | jq -r '.InstanceId')
    instance_zone=$(echo $instance_dict | jq -r '.Placement.AvailabilityZone')
    instance_public_ip=$(echo $instance_dict | jq -r '.PublicIpAddress')
    instance_public_ip=$(echo $instance_dict | jq -r '.PrivateIpAddress')
    
    device_dict=$(echo $instance_dict | jq -r '.BlockDeviceMappings')
    root_device_name=$(echo $instance_dict | jq -r '.RootDeviceName')
    root_device_dict=$(echo $device_dict | jq ".[] | select(.DeviceName == \"$root_device_name\")")
    volumeId=$(echo $root_device_dict | jq -r '.Ebs.VolumeId')
else
    echo "Instance not found"
    exit 1
fi

# exit 1

# Stop the instance and wait
aws ec2 describe-instances --instance-ids $TARGET_INSTANCE --output text --query 'Reservations[*].Instances[*].State.Name'
aws ec2 stop-instances --instance-ids $TARGET_INSTANCE 2> /dev/null
echo "Stopping instance..."
aws ec2 wait instance-stopped --instance-ids $TARGET_INSTANCE
echo "Instance has been stopped"

# Detach root device
# aws ec2 detach-volume --volume-id $volumeId
echo "Detaching root volume..."
# aws ec2 wait volume-available --volume-ids $volumeId
echo "Volume detached"

# Start new instance
temp_instance=$(aws ec2 run-instances --image-id ami-089cc16f7f08c4457 --instance-type "t2.micro" --placement AvailabilityZone=$instance_zone --key-name $NEW_KEY --instance-initiated-shutdown-behavior terminate --query "Instances[*].InstanceId" --output text 2> command_ouput)
read_error "InvalidKeyPair.NotFound" command_ouput
echo "Starting instance..."
aws ec2 wait instance-running --instance-ids $temp_instance
echo "Instance ready"
new_instance_dict=$(aws ec2 describe-instances --instance-ids $temp_instance --query "Reservations[0].Instances[0]")
new_instance_public_ip=$(echo $new_instance_dict | jq -r '.PublicIpAddress')
new_instance_private_ip=$(echo $new_instance_dict | jq -r '.PrivateIpAddress')

# Attach root volume
NEW_DEVICE_NAME="/dev/xvdf"
# aws ec2 attach-volume --volume-id $volumeId --instance-id $temp_instance --device $NEW_DEVICE_NAME
aws ec2 attach-volume --volume-id vol-0583efdf1c8deebf6 --instance-id $temp_instance --device $NEW_DEVICE_NAME

# Check instance connection
set -x
send_remote_command $USERNAME@$new_instance_private_ip "whoami " && export TEMP_INSTANCE=$new_instance_private_ip || send_remote_command $USERNAME@$new_instance_public_ip "whoami " && export TEMP_INSTANCE=$new_instance_public_ip
if [ "$?" = 255 ] ; then
    echo "there was an error"
    exit 1
fi
# ssh -tt ubuntu@$TEMP_INSTANCE < /dev/tty
ssh -tt ubuntu@$TEMP_INSTANCE << EOF
sudo -i
set +x
sudo mkdir /mnt/xvdf/
sudo mount ${NEW_DEVICE_NAME}1 /mnt/xvdf/
mount /dev/xvdf /source_root_device
cat /home/ubuntu/.ssh/authorized_keys >> /home/${USERNAME}/.ssh/authorized_keys
exit
exit
EOF