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

helm repo add gloo https://storage.googleapis.com/gloo-ee-helm
helm repo update

helm install -n gloo-system gloo glooe/gloo-ee \
--create-namespace \
--version $GLOO_VERSION \
--set-string license_key=$GLOO_GATEWAY_LICENSE_KEY \
-f -<<EOF
gloo:
  discovery:
    enabled: false
  gatewayProxies:
    gatewayProxy:
      disabled: true
  kubeGateway:
    enabled: true
  gloo:
    disableLeaderElection: true
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