#!/bin/bash

# First, need to check for the existence of a license key.
if [[ -z "${GLOO_GATEWAY_LICENSE_KEY}" ]]; then
  echo "Please set the GLOO_GATEWAY_LICENSE_KEY environment variable."
  exit 1
fi

GLOO_VERSION=1.18.6

# Install Argo CD
echo "Installing Argo CD"
kubectl apply -f https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.2.0/standard-install.yaml
kubectl create namespace argocd
until kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/v2.12.3/manifests/install.yaml > /dev/null 2>&1; do sleep 2; done
# wait for deployment to complete
kubectl -n argocd rollout status deploy/argocd-applicationset-controller
kubectl -n argocd rollout status deploy/argocd-dex-server
kubectl -n argocd rollout status deploy/argocd-notifications-controller
kubectl -n argocd rollout status deploy/argocd-redis
kubectl -n argocd rollout status deploy/argocd-repo-server
kubectl -n argocd rollout status deploy/argocd-server

# bcrypt(password)=$2a$10$79yaoOg9dL5MO8pn8hGqtO4xQDejSEVNWAGQR268JHLdrCw6UCYmy
# password: solo.io
kubectl -n argocd patch secret argocd-secret \
  -p '{"stringData": {
    "admin.password": "$2a$10$79yaoOg9dL5MO8pn8hGqtO4xQDejSEVNWAGQR268JHLdrCw6UCYmy",
    "admin.passwordMtime": "'$(date +%FT%T%Z)'"
  }}'

echo "***"
echo "Argo CD installed"
echo "You will need to port-forward to access the Argo CD UI"
echo "kubectl port-forward svc/argocd-server -n argocd 8080:443"
echo "Then open your browser to https://localhost:8080 and login with username 'admin' and password 'solo.io'"
echo "You can also use the CLI to interact with Argo CD"
echo "argocd login localhost:8080 --insecure --username admin --password solo.io"
echo ""

echo "Installing Gloo Gateway Enterprise Edition"
kubectl apply -f- <<EOF
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: gloo-gateway-ee-helm
  namespace: argocd
spec:
  destination:
    namespace: gloo-system
    server: https://kubernetes.default.svc
  project: default
  source:
    chart: gloo-ee
    helm:
      skipCrds: false
      values: |
        gloo:
          discovery:
            enabled: false
          disableLeaderElection: true
          gatewayProxies:
            gatewayProxy:
              disabled: true
          kubeGateway:
            enabled: true
        gloo-fed:
          enabled: false
          glooFedApiserver:
            enable: false
        grafana:
          defaultInstallationEnabled: false
        license_key: ${GLOO_GATEWAY_LICENSE_KEY}
        observability:
          enabled: false
        prometheus:
          enabled: false
    repoURL: https://storage.googleapis.com/gloo-ee-helm
    targetRevision: $GLOO_VERSION
  syncPolicy:
    automated:
      # Prune resources during auto-syncing (default is false)
      prune: true
      # Sync the app in part when resources are changed only in the target Kubernetes cluster
      # but not in the git source (default is false).
      selfHeal: true
    syncOptions:
    - CreateNamespace=true
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