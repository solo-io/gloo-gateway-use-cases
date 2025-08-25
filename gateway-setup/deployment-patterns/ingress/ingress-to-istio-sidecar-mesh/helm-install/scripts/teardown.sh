#!/bin/bash

SCRIPT_DIR=$(dirname "$0")

kubectl delete httproute exclude-automtls -n gloo-system
kubectl delete upstream httpbin -n gloo-system
kubectl delete httproute bookinfo -n bookinfo
kubectl label ns httpbin istio-injection-
kubectl rollout restart deploy -n httpbin

kubectl -n bookinfo delete -f https://raw.githubusercontent.com/istio/istio/master/samples/bookinfo/platform/kube/bookinfo.yaml -l 'account'
kubectl -n bookinfo delete -f https://raw.githubusercontent.com/solo-io/gloo-mesh-use-cases/main/policy-demo/productpage-with-curl.yaml
kubectl -n bookinfo delete -f https://raw.githubusercontent.com/istio/istio/master/samples/bookinfo/platform/kube/bookinfo.yaml -l 'app'
kubectl delete ns bookinfo

istioctl uninstall --purge -y

sleep 30


# Execute installation script from get-started
$SCRIPT_DIR/../../../../get-started/uninstall.sh