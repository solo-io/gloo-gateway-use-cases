#!/bin/bash

# Preflight checks
if [[ -z "${GLOO_GATEWAY_LICENSE_KEY}" ]]; then
  echo "Please set the GLOO_GATEWAY_LICENSE_KEY environment variable."
  exit 1
fi

if [[ -z "${GLOO_VERSION}" ]]; then
  echo "Please set the GLOO_VERSION environment variable."
  exit 1
fi

if [[ -z "${ISTIO_VERSION}" ]]; then
  echo "Please set the ISTIO_VERSION environment variable."
  exit 1
fi

if [[ -z "${GLOO_MESH_LICENSE_KEY}" ]]; then
  echo "Please set the GLOO_MESH_LICENSE_KEY environment variable."
  exit 1
fi

if [[ -z "${GLOO_OPERATOR_VERSION}" ]]; then
  echo "Please set the GLOO_OPERATOR_VERSION environment variable."
  exit 1
fi

if [[ -z "${CLUSTER_NAME}" ]]; then
  echo "Please set the CLUSTER_NAME environment variable."
  exit 1
fi

if [[ -z "${REPO_KEY}" ]]; then
  echo "Please set the REPO_KEY environment variable."
  exit 1
fi

SCRIPT_DIR=$(dirname "$0")

# Before you begin
# Execute installation script from get-started
bash $SCRIPT_DIR/../../../../../../get-started/ent/helm/scripts/install-gloo-gateway.sh
bash $SCRIPT_DIR/../../../../../../get-started/common/scripts/deploy-httpbin.sh
bash $SCRIPT_DIR/../../../../../../get-started/common/scripts/setup-api-gateway.sh
bash $SCRIPT_DIR/../../../../../../get-started/common/scripts/expose-httpbin.sh

ISTIO_IMAGE=${ISTIO_VERSION}-solo

REPO=us-docker.pkg.dev/gloo-mesh/istio-${REPO_KEY}
HELM_REPO=us-docker.pkg.dev/gloo-mesh/istio-helm-${REPO_KEY}

# Step 1: Set up service mesh
echo "Setting up service mesh..."

# Install community edition of Istio according to istio.io/latest/docs/getting-started/
echo "Installing Istio..."
curl -L https://istio.io/downloadIstio | ISTIO_VERSION=${ISTIO_VERSION} sh -
export PATH=$PWD/istio-${ISTIO_VERSION}/bin:$PATH

helm upgrade --install istio-base oci://${HELM_REPO}/base \
-n istio-system \
--create-namespace \
--version ${ISTIO_VERSION} \
--set defaultRevision=main

kubectl create namespace istio-config

helm upgrade --install istiod oci://${HELM_REPO}/istiod \
--version ${ISTIO_IMAGE} \
--namespace istio-system \
--wait \
--set license.value=${GLOO_MESH_LICENSE_KEY} \
-f -<< EOF
pilot:
  enabled: true
  cni: 
    enabled: true
  env:
    PILOT_ENABLE_IP_AUTOALLOCATE: "true"
    PILOT_ENABLE_K8S_SELECT_WORKLOAD_ENTRIES: "false"
    PILOT_SKIP_VALIDATE_TRUST_DOMAIN: "true"
meshConfig:
  rootNamespace: istio-config
  trustDomain: ${CLUSTER_NAME}
  accessLogEncoding: JSON
  defaultConfig:
    proxyMetadata:
      ISTIO_META_DNS_CAPTURE: "true"
      ISTIO_META_DNS_AUTO_ALLOCATE: "true"
global:
  hub: ${REPO}
  tag: ${ISTIO_IMAGE}
  proxy:
    clusterDomain: cluster.local
  logAsJson: false
  network: ${CLUSTER_NAME}
  multiCluster:
    clusterName: ${CLUSTER_NAME}
  meshID: mesh1
EOF

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
            istioDiscoveryAddress: istiod-main.istio-system.svc:15012
            istioMetaClusterId: ${CLUSTER_NAME}
            istioMetaMeshId: mesh1
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
REVISION=$(kubectl get pod -l app=istiod -n istio-system -o jsonpath='{.items[0].metadata.labels.istio\.io/rev}')
kubectl label ns httpbin istio.io/rev=$REVISION --overwrite=true
kubectl rollout restart deployment httpbin -n httpbin
sleep 30

# Step 4: Setup mTLS routing for bookinfo
REVISION=main
kubectl create ns bookinfo
kubectl label namespace bookinfo istio.io/rev=$REVISION --overwrite=true

# deploy bookinfo application components for all versions less than v3
kubectl -n bookinfo apply -f https://raw.githubusercontent.com/istio/istio/1.25.2/samples/bookinfo/platform/kube/bookinfo.yaml -l 'app,version notin (v3)'
# deploy an updated product page with extra container utilities such as 'curl' and 'netcat'
kubectl -n bookinfo apply -f https://raw.githubusercontent.com/solo-io/gloo-mesh-use-cases/main/policy-demo/productpage-with-curl.yaml
# deploy all bookinfo service accounts
kubectl -n bookinfo apply -f https://raw.githubusercontent.com/istio/istio/1.25.2/samples/bookinfo/platform/kube/bookinfo.yaml -l 'account'

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

