#!/bin/bash

if [[ -z "${GLOO_GATEWAY_LICENSE_KEY}" ]]; then
  echo "Please set the GLOO_GATEWAY_LICENSE_KEY environment variable."
  exit 1
fi

if [[ -z "${GLOO_VERSION}" ]]; then
  echo "Please set the GLOO_VERSION environment variable."
  exit 1
fi

helm upgrade -n gloo-system gloo glooe/gloo-ee \
--create-namespace \
--set-string license_key=${GLOO_GATEWAY_LICENSE_KEY} \
--version ${GLOO_VERSION} \
-f -<< EOF
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
  gateway:
    validation:
      enabled: true
      alwaysAcceptResources: false
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

sleep 30