#!/bin/bash

# First, need to check for the existence of a license key.
if [[ -z "${GLOO_GATEWAY_LICENSE_KEY}" ]]; then
  echo "Please set the GLOO_GATEWAY_LICENSE_KEY environment variable."
  exit 1
fi

SCRIPT_DIR=$(dirname "$0")

# Before you begin
# Execute installation script from get-started
$SCRIPT_DIR/../../../get-started/install-ee-helm.sh

kubectl apply -f- <<EOF
apiVersion: gateway.networking.k8s.io/v1
kind: Gateway
metadata:
  name: my-http-gateway
  namespace: gloo-system
  labels:
    example: httpbin-mydomain
spec:
  gatewayClassName: gloo-gateway
  listeners:
  - protocol: HTTP
    port: 8080
    hostname: mydomain.com
    name: http
    allowedRoutes:
      namespaces:
        from: All
EOF

kubectl apply -f- <<EOF
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: httpbin-mydomain
  namespace: httpbin
  labels:
    example: httpbin-mydomain
spec:
  parentRefs:
    - name: my-http-gateway
      namespace: gloo-system
  rules:
    - backendRefs:
        - name: httpbin
          port: 8000
EOF