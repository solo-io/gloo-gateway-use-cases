#!/bin/bash

# Preflight checks
REVISION=gloo

kubectl create ns bookinfo
kubectl label namespace bookinfo istio.io/rev=${REVISION} --overwrite

# deploy reviews and ratings services
kubectl -n bookinfo apply -f https://raw.githubusercontent.com/istio/istio/1.27.0/samples/bookinfo/platform/kube/bookinfo.yaml -l 'service in (reviews)'
# deploy reviews-v3
kubectl -n bookinfo apply -f https://raw.githubusercontent.com/istio/istio/1.27.0/samples/bookinfo/platform/kube/bookinfo.yaml -l 'app in (reviews),version in (v3)'
# deploy ratings
kubectl -n bookinfo apply -f https://raw.githubusercontent.com/istio/istio/1.27.0/samples/bookinfo/platform/kube/bookinfo.yaml -l 'app in (ratings)'
# deploy reviews and ratings service accounts
kubectl -n bookinfo apply -f https://raw.githubusercontent.com/istio/istio/1.27.0/samples/bookinfo/platform/kube/bookinfo.yaml -l 'account in (reviews, ratings)'

