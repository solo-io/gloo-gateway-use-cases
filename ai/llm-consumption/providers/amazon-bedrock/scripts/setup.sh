#!/usr/bin/env bash

# Preflight checks
if [[ -z "$AWS_ACCESS_KEY_ID" ]]; then
  echo "Error: AWS_ACCESS_KEY_ID environment variable is not set."
  exit 1
fi

if [[ -z "$AWS_SECRET_ACCESS_KEY" ]]; then
  echo "Error: AWS_SECRET_ACCESS_KEY environment variable is not set."
  exit 1
fi

if [[ -z "$AWS_SESSION_TOKEN" ]]; then
  echo "Error: AWS_SESSION_TOKEN environment variable is not set."
  exit 1
fi

# Setup an agentgateway proxy
SCRIPT_DIR=$(dirname "$0")

bash "$SCRIPT_DIR/../../../../../get-started/agentgateway/scripts/install-agent-gateway.sh"

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

# Create a secret with your Bedrock API.
kubectl create secret generic bedrock-secret \
-n gloo-system \
--from-literal=accessKey="$AWS_ACCESS_KEY_ID" \
--from-literal=secretKey="$AWS_SECRET_ACCESS_KEY" \
--from-literal=sessionToken="$AWS_SESSION_TOKEN" \
--type=Opaque \
--dry-run=client -o yaml | kubectl apply -f -

# Create a Backend resource to configure the LLM provider that references the AI API key secret
kubectl apply -f- <<EOF
apiVersion: gateway.kgateway.dev/v1alpha1
kind: Backend
metadata:
  name: bedrock
  namespace: gloo-system
spec:
  type: AI
  ai:
    llm:
      bedrock:
        model: "amazon.titan-text-lite-v1"
        region: us-east-1
        auth:
          type: Secret
          secretRef:
            name: bedrock-secret
EOF

# Create an HTTPRoute to route traffic to the Bedrock backend via the agentgateway
kubectl apply -f- <<EOF
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: bedrock
  namespace: gloo-system
spec:
  parentRefs:
    - name: agentgateway
      namespace: gloo-system
  rules:
  - matches:
    - path:
        type: PathPrefix
        value: /bedrock
    backendRefs:
    - name: bedrock
      namespace: gloo-system
      group: gateway.kgateway.dev
      kind: Backend
EOF


# Deploy netshoot for testing
kubectl apply -f- <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: netshoot
  namespace: default
spec:
  replicas: 1
  selector:
    matchLabels:
      app: netshoot
  template:
    metadata:
      labels:
        app: netshoot
    spec:
      containers:
      - name: netshoot
        image: nicolaka/netshoot
        command: ["sleep", "3600"]
EOF