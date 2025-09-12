#!/bin/bash

SCRIPT_DIR=$(dirname "$0")

k3d cluster delete mgmt
k3d cluster delete cluster1
k3d cluster delete cluster2

docker network rm k3d-cluster-network
rm -f $SCRIPT_DIR/../resources/test-kubeconfig.yaml
rm -f $SCRIPT_DIR/../.env