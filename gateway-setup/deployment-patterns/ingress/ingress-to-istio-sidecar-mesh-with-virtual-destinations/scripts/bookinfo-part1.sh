#!/bin/bash

# Preflight checks
REVISION=gloo

kubectl create ns bookinfo
kubectl label namespace bookinfo istio.io/rev=${REVISION} --overwrite

# deploy bookinfo application components for all versions less than v3
kubectl -n bookinfo apply -f https://raw.githubusercontent.com/istio/istio/1.27.0/samples/bookinfo/platform/kube/bookinfo.yaml -l 'app,version notin (v3)'
# deploy an updated product page with extra container utilities such as 'curl' and 'netcat'
kubectl -n bookinfo apply -f https://raw.githubusercontent.com/solo-io/gloo-mesh-use-cases/main/policy-demo/productpage-with-curl.yaml
# deploy all bookinfo service accounts
kubectl -n bookinfo apply -f https://raw.githubusercontent.com/istio/istio/1.27.0/samples/bookinfo/platform/kube/bookinfo.yaml -l 'account'

