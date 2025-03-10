#!/bin/bash

echo "This script assumes your current context is the EKS cluster you want to install the add-on to."
echo "If you are not sure, please run 'kubectl config current-context' to check your current context."

if [[ -z "${AWS_REGION}" ]]; then
    echo "Please provide the AWS region in the AWS_REGION env variable."
    exit 1
fi

if [[ -z "${AWS_CLUSTER}" ]]; then
    echo "Please provide the EKS cluster name in the AWS_CLUSTER env variable."
    exit 1
fi

echo "Installing the Gloo Gateway add-on for Amazon EKS..."
aws eks create-addon --cluster-name ${AWS_CLUSTER} --region ${AWS_REGION} \
--addon-name solo-io_gloo-gateway \
--addon-version v1.18.2-eksbuild.1

sleep 60

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