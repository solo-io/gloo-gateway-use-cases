#!/bin/bash

SCRIPT_DIR=$(dirname "$0")

kubectl delete gateway gloo-waypoint -n httpbin
kubectl -n httpbin delete deployment client
kubectl -n httpbin delete service client
kubectl -n httpbin delete sa client
kubectl -n httpbin delete deployment httpbin3
kubectl -n httpbin delete service httpbin3
kubectl -n httpbin delete sa httpbin3
kubectl -n httpbin delete deployment httpbin2
kubectl -n httpbin delete service httpbin2
kubectl -n httpbin delete sa httpbin2
kubectl delete ns httpbin

kubectl delete servicemeshcontroller managed-istio -n gloo-mesh

sleep 30

helm delete gloo-operator -n gloo-mesh

# Execute installation script from get-started
$SCRIPT_DIR/../../../../get-started/uninstall.sh