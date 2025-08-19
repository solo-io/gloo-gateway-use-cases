#!/bin/bash

SCRIPT_DIR=$(dirname "$0")

# Before you begin
# Execute installation script from get-started
bash $SCRIPT_DIR/../../../../../../../get-started/ent/helm/scripts/install-gloo-gateway.sh
bash $SCRIPT_DIR/../../../../../../../get-started/common/scripts/deploy-httpbin.sh
bash $SCRIPT_DIR/../../../../../../../get-started/common/scripts/setup-api-gateway.sh
bash $SCRIPT_DIR/../../../../../../../get-started/common/scripts/expose-httpbin.sh

# Step 1: Set up an ambient mesh
echo "Setting up an ambient mesh..."
curl -sSL https://get.ambientmesh.io | bash -

sleep 30

# Step 2: Set up Gloo Gateway for ingress
echo "Setting up Gloo Gateway for ingress..."
kubectl label ns gloo-system istio.io/dataplane-mode=ambient
kubectl label ns httpbin istio.io/dataplane-mode=ambient

# Step 3: Expose the Bookinfo sample app
echo "Exposing the Bookinfo sample app..."
kubectl create ns bookinfo
kubectl label namespace bookinfo istio.io/dataplane-mode=ambient

# deploy bookinfo application components for all versions
kubectl -n bookinfo apply -f https://raw.githubusercontent.com/istio/istio/master/samples/bookinfo/platform/kube/bookinfo.yaml -l 'app'
# deploy an updated product page with extra container utilities such as 'curl' and 'netcat'
kubectl -n bookinfo apply -f https://raw.githubusercontent.com/solo-io/gloo-mesh-use-cases/main/policy-demo/productpage-with-curl.yaml
# deploy all bookinfo service accounts
kubectl -n bookinfo apply -f https://raw.githubusercontent.com/istio/istio/master/samples/bookinfo/platform/kube/bookinfo.yaml -l 'account'

sleep 30 # Wait for the bookinfo pods to be ready

kubectl apply -n bookinfo -f- <<EOF
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: bookinfo
spec:
  parentRefs:
  - name: http
    namespace: gloo-system
  rules:
  - matches:
    - path:
        type: Exact
        value: /productpage
    - path:
        type: PathPrefix
        value: /static
    - path:
        type: Exact
        value: /login
    - path:
        type: Exact
        value: /logout
    - path:
        type: PathPrefix
        value: /api/v1/products
    backendRefs:
      - name: productpage
        port: 9080
EOF


echo "Setup complete.  Run tests via 'chainsaw test'"