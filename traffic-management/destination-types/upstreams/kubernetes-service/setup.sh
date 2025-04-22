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

# Se up the Upstream
kubectl apply -f https://raw.githubusercontent.com/solo-io/gloo/v1.16.x/example/petstore/petstore.yaml

kubectl apply -f- <<EOF
apiVersion: gloo.solo.io/v1
kind: Upstream
metadata:
  name: petstore
  namespace: gloo-system
spec:
  kube:
    serviceName: petstore
    serviceNamespace: default
    servicePort: 8080
EOF

kubectl apply -f- <<EOF
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: kube-upstream
  namespace: gloo-system
spec:
  parentRefs:
  - name: http
    namespace: gloo-system
  hostnames:
    - kube.example
  rules:
    - backendRefs:
      - name: petstore
        kind: Upstream
        group: gloo.solo.io
EOF


echo "Completed setup.  Run tests via 'chainsaw test'"