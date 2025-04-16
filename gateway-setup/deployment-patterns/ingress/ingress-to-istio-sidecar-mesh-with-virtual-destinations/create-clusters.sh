#!/bin/bash
# Create three local clusters
echo "Creating clusters..."
colima start --profile mgmt --cpu 2 --memory 8 --kubernetes
colima start --profile cluster1 --cpu 4 --memory 8 --kubernetes
colima start --profile cluster2 --cpu 4 --memory 8 --kubernetes

# Rename the contexts
echo "Renaming contexts..."
kubectl config rename-context colima-mgmt mgmt
kubectl config rename-context colima-cluster1 cluster1
kubectl config rename-context colima-cluster2 cluster2

echo "Done."