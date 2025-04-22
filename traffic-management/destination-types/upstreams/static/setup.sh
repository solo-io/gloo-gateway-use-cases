#!/bin/bash

# First, need to check for the existence of a license key.
if [[ -z "${GLOO_GATEWAY_LICENSE_KEY}" ]]; then
  echo "Please set the GLOO_GATEWAY_LICENSE_KEY environment variable."
  exit 1
fi

GLOO_VERSION=1.18.10

SCRIPT_DIR=$(dirname "$0")

# Execute installation script from get-started
$SCRIPT_DIR/../../../../get-started/install-ee-helm.sh

# Setup a static upstream
kubectl apply -f- <<EOF
apiVersion: gloo.solo.io/v1
kind: Upstream
metadata:
  name: json-upstream
spec:
  static:
    hosts:
      - addr: jsonplaceholder.typicode.com
        port: 80
EOF

kubectl apply -f- <<EOF
apiVersion: gateway.solo.io/v1
kind: RouteOption
metadata:
  name: rewrite
  namespace: default
spec:
  options:
    hostRewrite: 'jsonplaceholder.typicode.com'
EOF

kubectl apply -f- <<EOF
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: static-upstream
  namespace: default
spec:
  parentRefs:
  - name: http
    namespace: gloo-system
  hostnames:
    - static.example
  rules:
    - backendRefs:
      - name: json-upstream
        kind: Upstream
        group: gloo.solo.io
      filters:
      - type: ExtensionRef
        extensionRef:
          group: gateway.solo.io
          kind: RouteOption
          name: rewrite
EOF


echo "Completed setup.  Run tests via 'chainsaw test'"