#!/bin/bash
#
# Use this script to create the clusters.  This is necessary to run before testing as chainsaw requires a cluster to run against.


SCRIPT_DIR=$(dirname "$0")

# Create a k3d cluster with a local registry
echo "Creating management cluster..."
docker network create k3d-cluster-network 
k3d cluster create --config $SCRIPT_DIR/../resources/gloo.yaml
k3d kubeconfig merge gloo --output $SCRIPT_DIR/../resources/test-kubeconfig.yaml
k3d cluster create --config $SCRIPT_DIR/../resources/worker.yaml
k3d kubeconfig merge worker --output $SCRIPT_DIR/../resources/test-kubeconfig.yaml
