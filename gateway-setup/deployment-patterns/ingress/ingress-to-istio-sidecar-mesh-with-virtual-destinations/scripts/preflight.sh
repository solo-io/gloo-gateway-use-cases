#!/bin/bash

SCRIPT_DIR=$(dirname "$0")

# Create a k3d cluster with a local registry
echo "Creating management cluster..."
docker network create k3d-cluster-network 
k3d cluster create --config $SCRIPT_DIR/../resources/cluster1.yaml
k3d kubeconfig merge cluster1 --output $SCRIPT_DIR/../resources/test-kubeconfig.yaml
k3d cluster create --config $SCRIPT_DIR/../resources/cluster2.yaml
k3d kubeconfig merge cluster2 --output $SCRIPT_DIR/../resources/test-kubeconfig.yaml
k3d cluster create --config $SCRIPT_DIR/../resources/mgmt.yaml
k3d kubeconfig merge mgmt --output $SCRIPT_DIR/../resources/test-kubeconfig.yaml