#!/bin/bash

# Preflight checks
# First, need to check for the existence of a license key.
if [[ -z "${GLOO_MESH_LICENSE_KEY}" ]]; then
  echo "Please set the GLOO_MESH_LICENSE_KEY environment variable."
  exit 1
fi

# Solo distrubution of Istio patch version
# in the format 1.x.x, with no tags
if [[ -z "${ISTIO_VERSION}" ]]; then
  echo "Please set the ISTIO_VERSION environment variable to the desired Istio version (e.g., 1.18.2)."
  exit 1
fi

ISTIO_IMAGE=${ISTIO_VERSION}-solo

if [[ -z "${GLOO_OPERATOR_VERSION}" ]]; then
  echo "Please set the GLOO_OPERATOR_VERSION environment variable to the desired Gloo Operator version (e.g., 0.1.0)."
  exit 1
fi

if [[ -z "${REPO_KEY}" ]]; then
  echo "Please set the REPO_KEY environment variable to the desired Istio repository key."
  exit 1
fi

REPO=us-docker.pkg.dev/gloo-mesh/istio-${REPO_KEY}
HELM_REPO=us-docker.pkg.dev/gloo-mesh/istio-helm-${REPO_KEY}

SCRIPT_DIR=$(dirname "$0")

# Before you begin
# Execute installation script from get-started
bash $SCRIPT_DIR/../../../../../../../get-started/ent/helm/scripts/install-gloo-gateway.sh
bash $SCRIPT_DIR/../../../../../../../get-started/common/scripts/deploy-httpbin.sh
bash $SCRIPT_DIR/../../../../../../../get-started/common/scripts/setup-api-gateway.sh
bash $SCRIPT_DIR/../../../../../../../get-started/common/scripts/expose-httpbin.sh

# Step 1: Set up an ambient mesh
echo "Setting up an ambient mesh..."
echo "Installing istioctl..."
curl -L https://istio.io/downloadIstio | ISTIO_VERSION=${ISTIO_VERSION} sh -
cd istio-${ISTIO_VERSION}
export PATH=$PWD/istio-${ISTIO_VERSION}/bin:$PATH

helm upgrade --install istio-base oci://${HELM_REPO}/base \
  --namespace istio-system \
  --create-namespace \
  --version ${ISTIO_IMAGE} \
  -f - <<EOF
  defaultRevision: ""
  profile: ambient
EOF

helm upgrade --install istiod oci://${HELM_REPO}/istiod \
--namespace istio-system \
--version ${ISTIO_IMAGE} \
-f - <<EOF
global:
  hub: ${REPO}
  proxy:
    clusterDomain: cluster.local
  tag: ${ISTIO_IMAGE}
istio_cni:
  namespace: istio-system
  enabled: true
meshConfig:
  accessLogFile: /dev/stdout
  defaultConfig:
    proxyMetadata:
      ISTIO_META_DNS_AUTO_ALLOCATE: "true"
      ISTIO_META_DNS_CAPTURE: "true"
env:
  PILOT_ENABLE_IP_AUTOALLOCATE: "true"
  PILOT_ENABLE_K8S_SELECT_WORKLOAD_ENTRIES: "true"
  PILOT_SKIP_VALIDATE_TRUST_DOMAIN: "true"
profile: ambient
license:
  value: ${GLOO_MESH_LICENSE_KEY}
EOF

helm upgrade --install istio-cni oci://${HELM_REPO}/cni \
  --namespace istio-system \
  --version ${ISTIO_IMAGE} \
  -f - <<EOF
ambient:
  dnsCapture: true
excludeNamespaces:
  - istio-system
  - kube-system
global:
  hub: ${REPO}
  tag: ${ISTIO_IMAGE}
profile: ambient
EOF

sleep 30

# Deploy the Ambient Dataplane
helm upgrade --install ztunnel oci://${HELM_REPO}/ztunnel \
--namespace istio-system \
--version ${ISTIO_IMAGE} \
-f - <<EOF
configValidation: true
enabled: true
env:
  L7_ENABLED: "true"
hub: ${REPO}
istioNamespace: istio-system
namespace: istio-system
profile: ambient
proxy:
  clusterDomain: cluster.local
tag: ${ISTIO_IMAGE}
terminationGracePeriodSeconds: 29
variant: distroless
EOF

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