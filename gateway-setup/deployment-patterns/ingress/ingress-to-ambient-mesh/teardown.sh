#!/bin/bash

SCRIPT_DIR=$(dirname "$0")

kubectl delete servicemeshcontroller managed-istio -n gloo-mesh

sleep 30

helm delete gloo-operator -n gloo-mesh

# Execute installation script from get-started
$SCRIPT_DIR/../../../../get-started/uninstall.sh