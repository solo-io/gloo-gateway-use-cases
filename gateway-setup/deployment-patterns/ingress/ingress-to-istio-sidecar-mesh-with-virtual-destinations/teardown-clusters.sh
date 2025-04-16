#!/bin/bash

# Delete three local clusters
echo "Deleting clusters..."
colima delete mgmt -f
colima delete cluster1 -f
colima delete cluster2 -f

kubectl config delete-context mgmt
kubectl config delete-context cluster1
kubectl config delete-context cluster2

echo "Done."