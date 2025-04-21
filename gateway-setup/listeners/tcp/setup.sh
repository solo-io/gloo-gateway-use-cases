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

kubectl apply -f https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.2.0/experimental-install.yaml
kubectl apply -f- <<EOF
apiVersion: v1
kind: Pod
metadata:
  labels:
    app: tcp-echo
  name: tcp-echo
  namespace: default
spec:
  containers:
  - image: soloio/tcp-echo:latest
    imagePullPolicy: IfNotPresent
    name: tcp-echo
  restartPolicy: Always
---
apiVersion: v1
kind: Service
metadata:
  labels:
    app: tcp-echo
  name: tcp-echo
  namespace: default
spec:
  ports:
  - name: tcp
    port: 1025
    protocol: TCP
    targetPort: 1025
  selector:
    app: tcp-echo
EOF

kubectl apply -f- <<EOF
apiVersion: gateway.networking.k8s.io/v1
kind: Gateway
metadata:
  name: tcp-gateway
  namespace: gloo-system
  labels:
    app: tcp-echo
spec:
  gatewayClassName: gloo-gateway
  listeners:
  - protocol: TCP
    port: 8000
    name: tcp
    allowedRoutes:
      kinds:
      - kind: TCPRoute
EOF

kubectl apply -f- <<EOF
apiVersion: gateway.networking.k8s.io/v1alpha2
kind: TCPRoute
metadata:
  name: tcp-route-echo
  namespace: gloo-system
  labels:
    app: tcp-echo
spec:
  parentRefs:
    - name: tcp-gateway
      namespace: gloo-system
      sectionName: tcp
  rules:
    - backendRefs:
        - name: tcp-echo
          namespace: default
          port: 1025
EOF