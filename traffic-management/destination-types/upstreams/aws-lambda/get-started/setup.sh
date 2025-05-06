SCRIPT_DIR=$(dirname "$0")

# Execute installation script from get-started
$SCRIPT_DIR/../../../../../get-started/install-ee-helm.sh

echo "Follow the steps in https://docs.solo.io/gateway/latest/traffic-management/destination-types/upstreams/lambda/get-started to set up the AWS Lambda upstreams"
echo "Completed setup.  Run tests via 'chainsaw test'"