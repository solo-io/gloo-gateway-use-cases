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

echo "Creating certs"
mkdir example_certs
# root cert
openssl req -x509 -sha256 -nodes -days 365 -newkey rsa:2048 -subj '/O=any domain/CN=*' -keyout example_certs/root.key -out example_certs/root.crt
openssl req -out example_certs/gateway.csr -newkey rsa:2048 -nodes -keyout example_certs/gateway.key -subj "/CN=*/O=any domain"
openssl x509 -req -sha256 -days 365 -CA example_certs/root.crt -CAkey example_certs/root.key -set_serial 0 -in example_certs/gateway.csr -out example_certs/gateway.crt
kubectl create secret tls -n gloo-system https \
  --key example_certs/gateway.key \
  --cert example_certs/gateway.crt
kubectl label secret https gateway=https --namespace gloo-system

echo "Creating HTTPS Listener"
kubectl apply -f- <<EOF
apiVersion: gateway.networking.k8s.io/v1
kind: Gateway
metadata:
  name: https
  namespace: gloo-system
  labels:
    gateway: https
spec:
  gatewayClassName: gloo-gateway
  listeners:
    - name: https
      port: 443
      protocol: HTTPS
      hostname: https.example.com
      tls:
        mode: Terminate
        certificateRefs:
          - name: https
            kind: Secret
      allowedRoutes:
        namespaces:
          from: All
EOF

kubectl apply -f- <<EOF
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: httpbin-https
  namespace: httpbin
  labels:
    example: httpbin-route
    gateway: https
spec:
  parentRefs:
    - name: https
      namespace: gloo-system
  rules:
    - backendRefs:
        - name: httpbin
          port: 8000
EOF

echo "Completed setup."