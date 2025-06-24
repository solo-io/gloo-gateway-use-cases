#!/bin/bash
#
# Use this script to create the cluster.  This is necessary to run before testing as chainsaw requires a cluster to run against.

registry=k3d-myregistry.localhost:5001
registry_localhost=localhost:5001

# Create a k3d cluster with a local registry
echo "Creating local cluster..."
docker network create k3d-cluster-network 
k3d registry create myregistry.localhost --port 5001
k3d cluster create --config ../resources/gloo.yaml
