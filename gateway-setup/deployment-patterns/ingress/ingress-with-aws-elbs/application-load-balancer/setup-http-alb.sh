#!/bin/bash

# First, need to check for the existence of a license key.
if [[ -z "${GLOO_GATEWAY_LICENSE_KEY}" ]]; then
  echo "Please set the GLOO_GATEWAY_LICENSE_KEY environment variable."
  exit 1
fi

# Check for AWS environment variables
if [[ -z "${CLUSTER_NAME}" ]]; then
  echo "Please set the CLUSTER_NAME environment variable."
  exit 1
fi

if [[ -z "${REGION}" ]]; then
  echo "Please set the REGION environment variable."
  exit 1
fi

if [[ -z "${AWS_ACCOUNT_ID}" ]]; then
  echo "Please set the AWS_ACCOUNT_ID environment variable."
  exit 1
fi

GLOO_VERSION=1.18.10

SCRIPT_DIR=$(dirname "$0")

# Execute installation script from get-started
$SCRIPT_DIR/../../../../../get-started/install-ee-helm.sh

echo "Completed basic installation"

IAM_POLICY_NAME=AWSLoadBalancerControllerIAMPolicyNew
IAM_SA=aws-load-balancer-controller

# Set up an IAM OIDC provider for a cluster to enable IAM roles for pods
eksctl utils associate-iam-oidc-provider \
 --region ${REGION} \
 --cluster ${CLUSTER_NAME} \
 --approve

echo "Associated IAM OIDC Provider."

# Fetch the IAM policy that is required for the Kubernetes service account
curl -o iam-policy.json https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/refs/heads/main/docs/install/iam_policy.json

# Create the IAM policy
aws iam create-policy \
 --policy-name ${IAM_POLICY_NAME} \
 --policy-document file://iam-policy.json 

echo "Created IAM Policy."

# Create the Kubernetes service account
eksctl create iamserviceaccount \
 --cluster=${CLUSTER_NAME} \
 --namespace=kube-system \
 --name=${IAM_SA} \
 --attach-policy-arn=arn:aws:iam::${AWS_ACCOUNT_ID}:policy/${IAM_POLICY_NAME} \
 --override-existing-serviceaccounts \
 --approve \
 --region ${REGION}

echo "Created IAM service account."

sleep 20

# Deploy the AWS Load Balancer Controller
kubectl apply -k "github.com/aws/eks-charts/stable/aws-load-balancer-controller/crds?ref=master"

helm repo add eks https://aws.github.io/eks-charts
helm repo update
helm install aws-load-balancer-controller eks/aws-load-balancer-controller \
  -n kube-system \
  --set clusterName=${CLUSTER_NAME} \
  --set serviceAccount.create=false \
  --set serviceAccount.name=${IAM_SA}

sleep 60

echo "Creating a new Gateway for simple HTTP ALB"

kubectl apply -f- <<EOF
kind: Gateway
apiVersion: gateway.networking.k8s.io/v1
metadata:
  name: alb
  namespace: gloo-system
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

kubectl apply -f- <<EOF
apiVersion: gateway.solo.io/v1
kind: HttpListenerOption
metadata:
  name: alb-healthcheck
  namespace: gloo-system
spec:
  targetRefs:
  - group: gateway.networking.k8s.io
    kind: Gateway
    name: alb
  options:
    healthCheck:
      path: "/healthz"
EOF

echo "Creating an Ingress for the ALB"
kubectl apply -f- <<EOF
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  namespace: gloo-system
  name: alb
  annotations:
    alb.ingress.kubernetes.io/scheme: internet-facing
    alb.ingress.kubernetes.io/target-type: instance
    alb.ingress.kubernetes.io/healthcheck-protocol: HTTP #--HTTPS by default
    alb.ingress.kubernetes.io/healthcheck-path: "/healthz"
spec:
  ingressClassName: alb
  rules:
    - http:
        paths:
        - path: /
          pathType: Prefix
          backend:
            service:
              name: gloo-proxy-alb
              port:
                number: 8080
EOF

kubectl apply -f- <<EOF
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: httpbin-alb
  namespace: httpbin
  labels:
    example: httpbin-route
spec:
  parentRefs:
    - name: alb
      namespace: gloo-system
  hostnames:
    - "albtest.com"
  rules:
    - backendRefs:
        - name: httpbin
          port: 8000
EOF

echo "Completed setup.  Run tests via 'chainsaw test'"