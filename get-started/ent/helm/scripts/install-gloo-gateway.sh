#!/bin/bash

if [ -z "$GLOO_VERSION" ]; then
    echo "GLOO_VERSION is not set. Please set it to the desired version."
    exit 1
fi
kubectl apply -f https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.2.1/standard-install.yaml

helm repo add gloo https://storage.googleapis.com/solo-public-helm
helm repo update

helm install -n gloo-system gloo gloo/gloo \
--create-namespace \
--version $GLOO_VERSION \
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