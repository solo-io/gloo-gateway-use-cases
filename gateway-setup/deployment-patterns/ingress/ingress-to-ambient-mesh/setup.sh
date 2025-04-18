#!/bin/bash

# First, need to check for the existence of a license key.
if [[ -z "${GLOO_GATEWAY_LICENSE_KEY}" ]]; then
  echo "Please set the GLOO_GATEWAY_LICENSE_KEY environment variable."
  exit 1
fi

GLOO_VERSION=1.18.10

SCRIPT_DIR=$(dirname "$0")

# Before you begin
# Execute installation script from get-started
$SCRIPT_DIR/../../../../get-started/install-ee-helm.sh

# Step 1: Set up an ambient mesh
echo "Setting up an ambient mesh..."

# First, need to check for the existence of a license key.
if [[ -z "${GLOO_MESH_LICENSE_KEY}" ]]; then
  echo "Please set the GLOO_MESH_LICENSE_KEY environment variable."
  exit 1
fi

# Solo distrubution of Istio patch version
# in the format 1.x.x, with no tags
export ISTIO_VERSION=1.24.2
curl -L https://istio.io/downloadIstio | ISTIO_VERSION=${ISTIO_VERSION} sh -
cd istio-${ISTIO_VERSION}
export PATH=$PWD/istio-${ISTIO_VERSION}/bin:$PATH

helm install gloo-operator oci://us-docker.pkg.dev/solo-public/gloo-operator-helm/gloo-operator \
--version 0.1.0 \
-n gloo-mesh \
--create-namespace \
--set manager.env.SOLO_ISTIO_LICENSE_KEY=$GLOO_MESH_LICENSE_KEY

kubectl apply -n gloo-mesh -f -<<EOF
apiVersion: operator.gloo.solo.io/v1
kind: ServiceMeshController
metadata:
  name: managed-istio
  labels:
    app.kubernetes.io/name: managed-istio
spec:
  dataplaneMode: Ambient
  installNamespace: istio-system
  version: ${ISTIO_VERSION}
EOF

sleep 60

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