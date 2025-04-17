#!/bin/bash

# First, need to check for the existence of a license key.
if [[ -z "${GLOO_GATEWAY_LICENSE_KEY}" ]]; then
  echo "Please set the GLOO_GATEWAY_LICENSE_KEY environment variable."
  exit 1
fi

# Check for CLUSTER_NAME
if [[ -z "${CLUSTER_NAME}" ]]; then
  echo "Please set the CLUSTER_NAME environment variable."
  exit 1
fi

GLOO_VERSION=1.18.10

SCRIPT_DIR=$(dirname "$0")

# Before you begin
# Execute installation script from get-started
$SCRIPT_DIR/../../../../get-started/install-ee-helm.sh

# Step 1: Set up service mesh
echo "Setting up service mesh..."

# Install community edition of Istio according to istio.io/latest/docs/getting-started/
ISTIO_VERSION=1.22.8
echo "Installing Istio..."
curl -L https://istio.io/downloadIstio | ISTIO_VERSION=${ISTIO_VERSION} sh -
export PATH=$PWD/istio-${ISTIO_VERSION}/bin:$PATH

istioctl install -f istio-${ISTIO_VERSION}/samples/bookinfo/demo-profile-no-gateways.yaml -y
sleep 30

# Step 2: Enable Istio integration in Gloo Gateway
echo "Enabling Istio integration in Gloo Gateway..."
helm upgrade --install -n gloo-system gloo glooe/gloo-ee \
--set-string license_key=${GLOO_GATEWAY_LICENSE_KEY} \
--version ${GLOO_VERSION} \
-f -<< EOF
global:
  istioIntegration: 
    enableAutoMtls: true
    enabled: true
  istioSDS:
    enabled: true
gloo:
  discovery:
    enabled: false
  gatewayProxies:
    gatewayProxy:
      disabled: true
  gloo:
    disableLeaderElection: true
  kubeGateway:
    enabled: true
    gatewayParameters:
      glooGateway:
        istio:
          istioProxyContainer:
            istioDiscoveryAddress: istiod.istio-system.svc:15012
            istioMetaClusterId: ${CLUSTER_NAME}
            istioMetaMeshId: ${CLUSTER_NAME}
gloo-fed:
  enabled: false
  glooFedApiserver:
    enable: false
grafana:
  defaultInstallationEnabled: false
observability:
  enabled: false
prometheus:
  enabled: false
EOF

sleep 30

# Step 3: Setup mTLS routing to httpbin
echo "Setting up mTLS routing to httpbin..."
kubectl label ns httpbin istio-injection=enabled --overwrite=true
kubectl rollout restart deployment httpbin -n httpbin
sleep 30

# Step 4: Setup mTLS routing for bookinfo
REVISION=main
kubectl create ns bookinfo
kubectl label namespace bookinfo istio-injection=enabled --overwrite=true

# deploy bookinfo application components for all versions less than v3
kubectl -n bookinfo apply -f https://raw.githubusercontent.com/istio/istio/master/samples/bookinfo/platform/kube/bookinfo.yaml -l 'app,version notin (v3)'
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

# Step 5: Exclude a service from mTLS
echo "Excluding a service from mTLS..."
kubectl apply -f- <<EOF
apiVersion: gloo.solo.io/v1
kind: Upstream
metadata:
  name: httpbin
  namespace: gloo-system
spec:
  disableIstioAutoMtls: true
  kube:
    serviceName: httpbin
    serviceNamespace: httpbin
    servicePort: 8000
EOF

kubectl apply -f- <<EOF
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: exclude-automtls
  namespace: gloo-system
spec:
  parentRefs:
  - name: http
    namespace: gloo-system
  hostnames:
    - disable-automtls.example
  rules:
    - backendRefs:
      - name: httpbin
        kind: Upstream
        group: gloo.solo.io
EOF

echo "Setup complete.  Run tests via 'chainsaw test'"