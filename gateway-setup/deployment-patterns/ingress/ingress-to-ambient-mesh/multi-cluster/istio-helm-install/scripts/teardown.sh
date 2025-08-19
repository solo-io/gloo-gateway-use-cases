#!/bin/bash

SCRIPT_DIR=$(dirname "$0")

kubectl delete httproute bookinfo -n bookinfo
kubectl -n bookinfo delete -f https://raw.githubusercontent.com/istio/istio/master/samples/bookinfo/platform/kube/bookinfo.yaml -l 'account'
kubectl -n bookinfo delete -f https://raw.githubusercontent.com/solo-io/gloo-mesh-use-cases/main/policy-demo/productpage-with-curl.yaml
kubectl -n bookinfo delete -f https://raw.githubusercontent.com/istio/istio/master/samples/bookinfo/platform/kube/bookinfo.yaml -l 'app'
kubectl delete ns bookinfo

kubectl delete servicemeshcontroller managed-istio -n gloo-mesh

sleep 30

helm delete gloo-operator -n gloo-mesh

# Execute installation script from get-started
$SCRIPT_DIR/../../../../get-started/uninstall.sh