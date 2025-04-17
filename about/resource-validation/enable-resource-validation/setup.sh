#!/bin/bash

# First, need to check for the existence of a license key.
if [[ -z "${GLOO_GATEWAY_LICENSE_KEY}" ]]; then
  echo "Please set the GLOO_GATEWAY_LICENSE_KEY environment variable."
  exit 1
fi

GLOO_VERSION=1.18.10

SCRIPT_DIR=$(dirname "$0")

# Execute installation script from get-started
$SCRIPT_DIR/../../../get-started/install-ee-helm.sh

# Upgrade the installation to turn on validation
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

# Wait for install to complete
sleep 30

echo "Setup complete.  Run tests via 'chainsaw test'"