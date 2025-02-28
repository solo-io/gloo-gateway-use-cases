#!/bin/sh
GLOO_VERSION=1.18.9

# The script meat.
echo "Installing the latest Gloo CLI..."
curl -sL https://run.solo.io/gloo/install | sh
export PATH=$HOME/.gloo/bin:$PATH

# Installing Gloo Gateway OSS
echo "Installing Kubernetes Gateway via Helm..."
kubectl apply -f https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.2.0/standard-install.yaml
helm repo add gloo https://storage.googleapis.com/solo-public-helm
helm repo update
helm install -n gloo-system gloo gloo/gloo \
--create-namespace \
--version ${GLOO_VERSION} \
-f -<<EOF
discovery:
  enabled: false
gatewayProxies:
  gatewayProxy:
    disabled: true
gloo:
  disableLeaderElection: true
kubeGateway:
  enabled: true
EOF

sleep 30

# Setup an API Gateway
echo "Setting up an API Gateway..."
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

# Deploy a simple app.
echo "Deploying a simple app..."
kubectl create ns httpbin
kubectl -n httpbin apply -f https://raw.githubusercontent.com/solo-io/gloo-mesh-use-cases/main/policy-demo/httpbin.yaml

sleep 30

# Expose the app on the gateway
echo "Exposing the app on the gateway..."
kubectl apply -f- <<EOF
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: httpbin
  namespace: httpbin
  labels:
    example: httpbin-route
spec:
  parentRefs:
    - name: http
      namespace: gloo-system
  hostnames:
    - "www.example.com"
  rules:
    - backendRefs:
        - name: httpbin
          port: 8000
EOF

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

echo "You should be setup now.  Try testing!"