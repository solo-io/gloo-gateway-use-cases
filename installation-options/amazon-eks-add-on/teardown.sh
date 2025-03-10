#!/bin/bash

SCRIPT_DIR=$(dirname "$0")

if [[ -z "${AWS_REGION}" ]]; then
    echo "Please provide the AWS region in the AWS_REGION env variable."
    exit 1
fi

if [[ -z "${AWS_CLUSTER}" ]]; then
    echo "Please provide the EKS cluster name in the AWS_CLUSTER env variable."
    exit 1
fi

echo "Uninstalling the Gloo Gateway add-on for Amazon EKS..."
eksctl delete addon --name solo-io_gloo-gateway --cluster ${AWS_CLUSTER} --region ${AWS_REGION}


# Execute installation script from get-started
$SCRIPT_DIR/../../get-started/uninstall.sh