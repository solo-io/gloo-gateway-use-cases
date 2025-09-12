#!/bin/bash

# Preflight checks
if [[ -z "${ISTIO_VERSION}" ]]; then
  echo "ISTIO_VERSION is not set"
  exit 1
fi

if [[ -z "${CLUSTER}" ]]; then
  echo "CLUSTER is not set"
  exit 1
fi

if [[ -z "${REPO}" ]]; then
  echo "REPO is not set"
  exit 1
fi

REVISION=gloo

helm upgrade --install istio-eastwestgateway istio/gateway \
--version ${ISTIO_VERSION} \
--namespace istio-eastwest \
--create-namespace \
--wait \
-f - <<EOF
revision: ${REVISION}
global:
  hub: ${REPO}
  tag: ${ISTIO_VERSION}-solo
  network: ${CLUSTER}
  multiCluster:
    clusterName: ${CLUSTER}
name: istio-eastwestgateway
labels:
  app: istio-eastwestgateway
  istio: eastwestgateway
  revision: ${REVISION}
  topology.istio.io/network: ${CLUSTER}
service:
  type: LoadBalancer
  ports:
    # Port for health checks on path /healthz/ready.
    # For AWS ELBs, this port must be listed first.
    - port: 15021
      targetPort: 15021
      name: status-port
    # Port for multicluster mTLS passthrough; required for Gloo Mesh east/west routing
    - port: 15443
      targetPort: 15443
      # Gloo Mesh looks for this default name 'tls' on a gateway
      name: tls
    # Port required for VM onboarding
    #- port: 15012
      #targetPort: 15012
      # Required for VM onboarding discovery address
      #name: tls-istiod
EOF
