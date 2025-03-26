#!/bin/bash

SCRIPT_DIR=$(dirname "$0")

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

IAM_POLICY_NAME=AWSLoadBalancerControllerIAMPolicyNew
IAM_SA=aws-load-balancer-controller

kubectl delete httproute httpbin-alb -n httpbin
kubectl delete ingress alb -n gloo-system
kubectl delete httplisteneroption alb-healthcheck -n gloo-system
kubectl delete gateway alb -n gloo-system

helm delete aws-load-balancer-controller -n kube-system
kubectl delete -k "github.com/aws/eks-charts/stable/aws-load-balancer-controller/crds?ref=master"

eksctl delete iamserviceaccount \
  --cluster=${CLUSTER_NAME} \
  --namespace=kube-system \
  --name=${IAM_SA} \
  --region ${REGION} 

aws iam delete-policy --policy-arn arn:aws:iam::${AWS_ACCOUNT_ID}:policy/${IAM_POLICY_NAME}

# Execute installation script from get-started
$SCRIPT_DIR/../../../../../get-started/uninstall.sh