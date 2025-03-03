#!/bin/sh

echo "Uninstalling Gloo Gateway"
kubectl delete -n httpbin httproute httpbin
kubectl delete gateway http -n gloo-system
glooctl uninstall --all
kubectl delete -f https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.2.0/standard-install.yaml

kubectl delete ns httpbin
kubectl delete deployment netshoot