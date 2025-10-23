#!/bin/bash

SCRIPT_DIR=$(dirname "$0")

bash "$SCRIPT_DIR/../../../get-started/agentgateway/scripts/install-agent-gateway.sh"

kubectl apply -f- <<EOF
kind: Gateway
apiVersion: gateway.networking.k8s.io/v1
metadata:
  name: agentgateway
  namespace: gloo-system
  labels:
    app: agentgateway
spec:
  gatewayClassName: agentgateway-enterprise
  listeners:
  - protocol: HTTP
    port: 8080
    name: http
    allowedRoutes:
      namespaces:
        from: All
EOF

