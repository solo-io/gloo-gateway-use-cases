#!/bin/bash

if [ -z "$GLOO_VERSION" ]; then
    echo "GLOO_VERSION is not set. Please set it to the desired version."
    exit 1
fi
kubectl apply -f https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.2.1/standard-install.yaml

glooctl install gateway \
--version $GLOO_VERSION \
--values - << EOF
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