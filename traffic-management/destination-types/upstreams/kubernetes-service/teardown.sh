#!/bin/bash

SCRIPT_DIR=$(dirname "$0")

kubectl delete -f https://raw.githubusercontent.com/solo-io/gloo/v1.16.x/example/petstore/petstore.yaml

# Execute installation script from get-started
$SCRIPT_DIR/../../../../get-started/uninstall.sh