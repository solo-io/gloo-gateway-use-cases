#!/bin/bash

kubectl create ns bookinfo
kubectl label namespace bookinfo istio.io/dataplane-mode=ambient

# deploy bookinfo application components for all versions
kubectl -n bookinfo apply -f https://raw.githubusercontent.com/istio/istio/1.26.2/samples/bookinfo/platform/kube/bookinfo.yaml -l 'app'
# deploy an updated product page with extra container utilities such as 'curl' and 'netcat'
kubectl -n bookinfo apply -f https://raw.githubusercontent.com/solo-io/gloo-mesh-use-cases/main/policy-demo/productpage-with-curl.yaml
# deploy all bookinfo service accounts
kubectl -n bookinfo apply -f https://raw.githubusercontent.com/istio/istio/1.26.2/samples/bookinfo/platform/kube/bookinfo.yaml -l 'account'
# deploy individual services for each microservice version
kubectl -n bookinfo apply -f https://raw.githubusercontent.com/istio/istio/1.26.2/samples/bookinfo/platform/kube/bookinfo-versions.yaml

kubectl label service productpage -n bookinfo solo.io/service-scope=global
kubectl annotate service productpage -n bookinfo networking.istio.io/traffic-distribution=Any