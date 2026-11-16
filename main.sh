#!/bin/bash

set -e

if [ $# -eq 0 ]; then
    echo "Usage: bash $0 'instance:description:port:source' ..."
    exit 1
fi

# Check and load .env file
if [ -f .env ]; then
    set -a          # Automatically exports all variables defined in .env
    source .env
    set +a
else
    echo "Error: .env file not found! Please create one."
    exit 1
fi

# (Optional) Validate required variables are present
: "${AMI_ID:?AMI_ID is missing in .env}"
: "${INSTANCE_TYPE:?INSTANCE_TYPE is missing in .env}"
: "${DOMAIN_NAME:?DOMAIN_NAME is missing in .env}"
: "${HOSTED_ZONE_ID:?HOSTED_ZONE_ID is missing in .env}"

SCRIPT_DIR=$(cygpath -m "$PWD")

MY_IP=$(curl -s https://checkip.amazonaws.com)
declare -A SG_IDS
INSTANCE_IPS=()

for ARG in "$@"; do
    # Split each argument by ':' into 4 variables
    IFS=":" read -r INSTANCE DESC PORT SOURCE <<< "$ARG"

    # Replace placeholders with dynamic values
    if [ "$SOURCE" = "MY_IP" ]; then
        SOURCE="${MY_IP}/32"
    elif [ -n "${SG_IDS[$SOURCE]}" ]; then
        SOURCE="${SG_IDS[$SOURCE]}"
    fi

    echo "Creating security group: $INSTANCE..."
    SG_ID=$(aws ec2 create-security-group \
        --group-name "$INSTANCE" \
        --description "$DESC" \
        --query 'GroupId' \
        --output text)

    # Store the generated GroupId by name for future rules in the loop
    SG_IDS["$INSTANCE"]="$SG_ID"

    # Check if source is a CIDR block (contains '/') or another Security Group ID
    if [[ "$SOURCE" == */* ]]; then
        aws ec2 authorize-security-group-ingress \
            --group-id "$SG_ID" \
            --protocol tcp \
            --port "$PORT" \
            --cidr "$SOURCE"
    else
        aws ec2 authorize-security-group-ingress \
            --group-id "$SG_ID" \
            --protocol tcp \
            --port "$PORT" \
            --source-group "$SOURCE"
    fi

    echo "Created $INSTANCE ($SG_ID) allowing port $PORT from $SOURCE"

    if [ $INSTANCE != "common" ]; then
        echo "creating instance: $INSTANCE"
        # creating temp user data to run instance with user data script
        TMP_USER_DATA="${SCRIPT_DIR}/.tmp_${INSTANCE}.sh"
        echo "#!/bin/bash" > "$TMP_USER_DATA"
        cat .env >> "$TMP_USER_DATA"
        echo "" >> "$TMP_USER_DATA"
        tail -n +2 "${SCRIPT_DIR}/${INSTANCE}.sh" >> "$TMP_USER_DATA"
        instance_id=$(aws ec2 run-instances \
                --image-id $AMI_ID \
                --instance-type $INSTANCE_TYPE \
                --security-group-ids "${SG_IDS["common"]}" "$SG_ID" \
                --user-data "file://${TMP_USER_DATA}" \
                --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=$INSTANCE}]" \
                --query 'Instances[0].InstanceId' \
                --output text)
        # delete the temp file
        rm -f "$TMP_USER_DATA"
        aws ec2 wait instance-running --instance-ids "$instance_id"
        PUBLIC_IP=$(aws ec2 describe-instances \
            --instance-ids "$instance_id" \
            --query 'Reservations[0].Instances[0].PublicIpAddress' \
            --output text)

        INSTANCE_IPS+=("$INSTANCE: $PUBLIC_IP")

        echo "$INSTANCE instance ID: $instance_id"

        if [ $INSTANCE != "frontend" ]; then
            IP=$(aws ec2 describe-instances \
                --instance-ids $instance_id \
                --query 'Reservations[0].Instances[0].PrivateIpAddress' \
                --output text
            )
            r53_record="$INSTANCE.$DOMAIN_NAME"
        else
            IP=$(aws ec2 describe-instances \
                --instance-ids $instance_id \
                --query 'Reservations[0].Instances[0].PublicIpAddress' \
                --output text
            )
            r53_record="$DOMAIN_NAME"
        fi

        #update route53 record
            echo "Record: ${r53_record}"
                aws route53 change-resource-record-sets \
                --hosted-zone-id $HOSTED_ZONE_ID \
                --change-batch '{
                    "Changes": [
                        {
                            "Action": "UPSERT",
                            "ResourceRecordSet": {
                                "Name": "'$r53_record'",
                                "Type": "A",
                                "TTL": 1,
                                "ResourceRecords": [{"Value": "'$IP'"}]
                            }
                        }
                    ]
                }'
        echo "Updated route53 record for $INSTANCE"
    fi
done

echo "Instances IPs"
(IFS=", "; echo "${INSTANCE_IPS[*]}")
echo ""
echo "Wait for 5min to install all dependecies. then browse application"
echo "ssh to each instance to check logs: 'sudo tail -f /var/log/cloud-init-output.log'"