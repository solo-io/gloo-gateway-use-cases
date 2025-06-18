#!/bin/bash

if [ -z "$GLOO_VERSION" ]; then
    echo "GLOO_VERSION is not set. Please set it to the desired version."
    exit 1
fi

if [ -z "$GLOO_GATEWAY_LICENSE_KEY" ]; then
    echo "GLOO_GATEWAY_LICENSE_KEY is not set. Please set it to the desired license key."
    exit 1
fi

kubectl apply -f https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.2.1/standard-install.yaml

glooctl install gateway enterprise \
--license-key $GLOO_GATEWAY_LICENSE_KEY \
--version $GLOO_VERSION \
--values - << EOF
gloo:
  discovery:
    enabled: false
  gatewayProxies:
    gatewayProxy:
      disabled: true
  gloo:
    disableLeaderElection: true
  kubeGateway:
    enabled: true
gloo-fed:
  enabled: false
  glooFedApiserver:
    enable: false
grafana:
  defaultInstallationEnabled: false
observability:
  enabled: false
prometheus:
  enabled: false
EOF