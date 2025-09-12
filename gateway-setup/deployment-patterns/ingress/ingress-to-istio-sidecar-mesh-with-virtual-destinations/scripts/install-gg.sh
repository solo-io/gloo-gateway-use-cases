#!/bin/bash

if [[ -z "${GLOO_GATEWAY_LICENSE_KEY}" ]]; then
  echo "Please set the GLOO_GATEWAY_LICENSE_KEY environment variable."
  exit 1
fi

if [[ -z "${GLOO_VERSION}" ]]; then
  echo "Please set the GLOO_VERSION environment variable."
  exit 1
fi

if [[ -z "${CLUSTER_NAME}" ]]; then
  echo "Please set the CLUSTER_NAME environment variable."
  exit 1
fi

# Experimental install required for VirtualDestination integration
kubectl apply -f https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.2.1/experimental-install.yaml

REVISION=gloo

helm repo add glooe https://storage.googleapis.com/gloo-ee-helm
helm repo update

helm install -n gloo-system gloo-gateway glooe/gloo-ee \
--create-namespace \
--version $GLOO_VERSION \
--set-string license_key=$GLOO_GATEWAY_LICENSE_KEY \
-f -<<EOF
gloo:
  discovery:
    enabled: false
  gatewayProxies:
    gatewayProxy:
      disabled: true
  kubeGateway:
    enabled: true
    gatewayParameters:
      glooGateway:
        istio:
          istioProxyContainer:
            istioDiscoveryAddress: istiod-${REVISION}.istio-system.svc:15012
            istioMetaClusterId: ${CLUSTER_NAME}
            istioMetaMeshId: ${CLUSTER_NAME}
  gloo:
    disableLeaderElection: true
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
global:
  istioSDS:
    enabled: true
  istioIntegration:
    enabled: true
    enableAutoMtls: true
EOF

sleep 15

kubectl apply -n gloo-system -f- <<EOF
kind: Gateway
apiVersion: gateway.networking.k8s.io/v1
metadata:
  name: http
spec:
  gatewayClassName: gloo-gateway
  listeners:
  - protocol: HTTP
    port: 8080
    name: http
    allowedRoutes:
      namespaces:
        from: All
EOF

sleep 10

kubectl apply -f - <<EOF
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: productpage
  namespace: bookinfo
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
      backendRefs:
        - name: productpage
          port: 9080
          namespace: bookinfo
EOF

kubectl apply -f - <<EOF
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: reviews
  namespace: gloo-system
spec:
  parentRefs:
    - name: http
      namespace: gloo-system
  rules:
    - matches:
      - path:
          type: PathPrefix
          value: /reviews
      backendRefs:
        - name: reviews.mesh.internal.com
          port: 9080
          kind: Hostname
          group: networking.istio.io
EOF