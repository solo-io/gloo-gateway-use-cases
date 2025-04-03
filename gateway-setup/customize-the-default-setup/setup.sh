#!/bin/bash

# First, need to check for the existence of a license key.
if [[ -z "${GLOO_GATEWAY_LICENSE_KEY}" ]]; then
  echo "Please set the GLOO_GATEWAY_LICENSE_KEY environment variable."
  exit 1
fi

GLOO_VERSION=1.18.8

SCRIPT_DIR=$(dirname "$0")

# Execute installation script from get-started
$SCRIPT_DIR/../../get-started/install-ee-helm.sh

echo "Creating a new GatewayParameters with label custom"
kubectl apply -f- <<EOF
apiVersion: gateway.gloo.solo.io/v1alpha1
kind: GatewayParameters
metadata:
  name: custom-gw-params
  namespace: gloo-system
spec:
  kube:
    service:
      type: NodePort
      extraLabels:
        gateway: custom
    podTemplate:
      extraLabels:
        gateway: custom
      securityContext:
        fsGroup: 50000
        runAsUser: 50000
EOF

echo "Creating a Gateway using the new GatewayParameters"
kubectl apply -f- <<EOF
kind: Gateway
apiVersion: gateway.networking.k8s.io/v1
metadata:
  name: custom
  namespace: gloo-system
  annotations:
    gateway.gloo.solo.io/gateway-parameters-name: "custom-gw-params"
spec:
  gatewayClassName: gloo-gateway
  listeners:
  - protocol: HTTP
    port: 80
    name: http
    allowedRoutes:
      namespaces:
        from: All
EOF

echo "Completed setup.  Run tests via 'chainsaw test'"