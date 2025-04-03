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

GLOO_VERSION=1.18.8

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

echo "Creating a new GatewayParameters for simple HTTP NLB"
kubectl apply -f- <<EOF
apiVersion: gateway.gloo.solo.io/v1alpha1
kind: GatewayParameters
metadata:
  name: custom-gw-params
  namespace: gloo-system
spec:
  kube:
    service:
      extraAnnotations:
        service.beta.kubernetes.io/aws-load-balancer-type: "external"
        service.beta.kubernetes.io/aws-load-balancer-scheme: internet-facing
        service.beta.kubernetes.io/aws-load-balancer-nlb-target-type: "instance"
EOF

kubectl apply -f- <<EOF
kind: Gateway
apiVersion: gateway.networking.k8s.io/v1
metadata:
  name: aws-cloud
  namespace: gloo-system
  annotations:
    gateway.gloo.solo.io/gateway-parameters-name: "custom-gw-params"
spec:
  gatewayClassName: gloo-gateway
  listeners:
  - protocol: HTTP
    port: 80
    name: http
    allowedRoutes:
      namespaces:
        from: All
EOF


kubectl apply -f- <<EOF
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: httpbin-elb
  namespace: httpbin
  labels:
    example: httpbin-route
spec:
  parentRefs:
    - name: aws-cloud
      namespace: gloo-system
  hostnames:
    - "www.nlb.com"
  rules:
    - backendRefs:
        - name: httpbin
          port: 8000
EOF

echo "Completed setup.  Run tests via 'chainsaw test'"