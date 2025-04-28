#!/bin/bash


GLOO_VERSION=1.18.10

SCRIPT_DIR=$(dirname "$0")

# Execute installation script from get-started
$SCRIPT_DIR/../../../../get-started/install-ee-helm.sh

echo "Follow the steps in https://docs.solo.io/gateway/latest/traffic-management/destination-types/upstreams/ec2 to set up the AWS EC2 upstreams"
echo "Completed setup.  Run tests via 'chainsaw test'"