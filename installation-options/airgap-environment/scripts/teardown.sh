#!/bin/bash

SCRIPT_DIR=$(dirname "$0")

# Remove the k3d cluster
k3d cluster delete gloo
docker network rm k3d-cluster-network
k3d registry delete myregistry.localhost