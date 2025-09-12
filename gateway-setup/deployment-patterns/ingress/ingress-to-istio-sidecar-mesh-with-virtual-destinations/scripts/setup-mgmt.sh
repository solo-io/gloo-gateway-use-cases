#!/bin/bash

# Preflight checks
if [[ -z "${GLOO_MESH_LICENSE_KEY}" ]]; then
  echo "Please set the GLOO_MESH_LICENSE_KEY environment variable."
  exit 1
fi

if [[ -z "${GLOO_MESH_VERSION}" ]]; then
  echo "Please set the GLOO_MESH_VERSION environment variable."
  exit 1
fi

if [[ -z "${MGMT_CLUSTER}" ]]; then
  echo "Please set the MGMT_CLUSTER environment variable."
  exit 1
fi

if [[ -z "${REMOTE_CLUSTER1}" ]]; then
  echo "Please set the REMOTE_CLUSTER1 environment variable."
  exit 1
fi

if [[ -z "${REMOTE_CONTEXT1}" ]]; then
  echo "Please set the REMOTE_CONTEXT1 environment variable."
  exit 1
fi

if [[ -z "${REMOTE_CONTEXT2}" ]]; then
  echo "Please set the REMOTE_CONTEXT2 environment variable."
  exit 1
fi

if [[ -z "${REMOTE_CLUSTER2}" ]]; then
  echo "Please set the REMOTE_CLUSTER2 environment variable."
  exit 1
fi


# Before you begin
# Install meshctl
echo "Installing meshctl..."
curl -sL https://run.solo.io/meshctl/install | GLOO_MESH_VERSION=v${GLOO_MESH_VERSION} sh -
MESHCTL=$HOME/.gloo-mesh/bin/meshctl

# Install the Gloo Mesh management plane
echo "Installing Gloo Mesh management plane..."
${MESHCTL} install --profiles mgmt-server \
--set common.cluster=${MGMT_CLUSTER} \
--set licensing.glooMeshLicenseKey=${GLOO_MESH_LICENSE_KEY} 

sleep 20

TELEMETRY_GATEWAY_IP=$(kubectl get svc -n gloo-mesh gloo-telemetry-gateway -o jsonpath="{.status.loadBalancer.ingress[0]['hostname','ip']}")
TELEMETRY_GATEWAY_PORT=$(kubectl get svc -n gloo-mesh gloo-telemetry-gateway -o jsonpath='{.spec.ports[?(@.name=="otlp")].port}')
TELEMETRY_GATEWAY_ADDRESS=${TELEMETRY_GATEWAY_IP}:${TELEMETRY_GATEWAY_PORT}
echo "TELEMETRY_GATEWAY_ADDRESS=${TELEMETRY_GATEWAY_ADDRESS}" >> .env

kubectl apply -f- <<EOF
apiVersion: admin.gloo.solo.io/v2
kind: Workspace
metadata:
  name: $MGMT_CLUSTER
  namespace: gloo-mesh
spec:
  workloadClusters:
    - name: '*'
      namespaces:
        - name: '*'
---
apiVersion: v1
kind: Namespace
metadata:
  name: gloo-mesh-config
---
apiVersion: admin.gloo.solo.io/v2
kind: WorkspaceSettings
metadata:
  name: $MGMT_CLUSTER
  namespace: gloo-mesh-config
spec:
  options:
    serviceIsolation:
      enabled: false
    federation:
      enabled: false
      serviceSelector:
      - {}
    eastWestGateways:
    - selector:
        labels:
          istio: eastwestgateway
EOF

# Install the Gloo data plane
echo "Installing Gloo data plane..."
meshctl cluster register $REMOTE_CLUSTER1 \
--remote-context $REMOTE_CONTEXT1 \
--profiles agent,ratelimit,extauth \
--telemetry-server-address $TELEMETRY_GATEWAY_ADDRESS

meshctl cluster register $REMOTE_CLUSTER2 \
--remote-context $REMOTE_CONTEXT2 \
--profiles agent,ratelimit,extauth \
--telemetry-server-address $TELEMETRY_GATEWAY_ADDRESS

sleep 30

