#!/bin/bash
#exit 0
SCRIPT_DIR=$(dirname "$0")

k3d cluster delete gloo
k3d cluster delete worker

docker network rm k3d-cluster-network
rm -f $SCRIPT_DIR/../resources/test-kubeconfig.yaml
rm -f $SCRIPT_DIR/../.env