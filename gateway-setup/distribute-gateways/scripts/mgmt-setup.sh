#!/bin/bash
# This script sets up the management cluster for Gloo Mesh and installs the meshctl utility.
# Before running this script, ensure your current context is set to the management cluster.

if [[ -z "${GLOO_MESH_VERSION}" ]]; then
  echo "GLOO_MESH_VERSION is not set. Please set it to the desired version."
  exit 1
fi

if [[ -z "${GLOO_MESH_LICENSE_KEY}" ]]; then
  echo "GLOO_MESH_LICENSE_KEY is not set. Please set it to your Gloo Mesh license key."
  exit 1
fi

if [[ -z "${GLOO_MESH_CLUSTER}" ]]; then
  echo "GLOO_MESH_CLUSTER is not set. Please set it to the name of your management cluster."
  exit 1
fi

if [[ -z "${REMOTE_CLUSTER}" ]]; then
  echo "REMOTE_CLUSTER is not set. Please set it to the name of your remote cluster."
  exit 1
fi

SCRIPT_DIR=$(dirname "$0")

# Download the meshctl utility
curl -sL https://run.solo.io/meshctl/install | GLOO_MESH_VERSION=v${GLOO_MESH_VERSION} sh -
MESHCTL=$HOME/.gloo-mesh/bin/meshctl

# Add and update the helm repository for Gloo Mesh 
helm repo add gloo-platform https://storage.googleapis.com/gloo-platform/helm-charts
helm repo update

# Install the Gloo CRDs
helm upgrade -i gloo-platform-crds gloo-platform/gloo-platform-crds \
  --namespace=gloo-mesh \
  --create-namespace \
  --set installEnterpriseCrds=true \
  --version=${GLOO_MESH_VERSION} 

# Install Gloo Gateway Enterprise
bash ${SCRIPT_DIR}/../../../get-started/ent/helm/scripts/install-gloo-gateway.sh

# Install Gloo Mesh
helm upgrade -i gloo-platform gloo-platform/gloo-platform \
  -n gloo-mesh \
  --version=${GLOO_MESH_VERSION} \
  --values ${SCRIPT_DIR}/../resources/mgmt-plane.yaml \
  --set common.cluster=${GLOO_MESH_CLUSTER} \
  --set licensing.glooMeshLicenseKey=${GLOO_MESH_LICENSE_KEY} 

kubectl wait --for=condition=Available=True --timeout=600s -n gloo-mesh deployment/gloo-mesh-mgmt-server

MGMT_SERVER_NETWORKING_DOMAIN=$(kubectl get svc -n gloo-mesh gloo-mesh-mgmt-server -o jsonpath="{.status.loadBalancer.ingress[0]['hostname','ip']}")
MGMT_SERVER_NETWORKING_PORT=$(kubectl get svc -n gloo-mesh gloo-mesh-mgmt-server -o jsonpath='{.spec.ports[?(@.name=="grpc")].port}')
MGMT_SERVER_NETWORKING_ADDRESS=${MGMT_SERVER_NETWORKING_DOMAIN}:${MGMT_SERVER_NETWORKING_PORT}
echo "MGMT_SERVER_NETWORKING_ADDRESS=${MGMT_SERVER_NETWORKING_ADDRESS}" >> .env

TELEMETRY_GATEWAY_IP=$(kubectl get svc -n gloo-mesh gloo-telemetry-gateway -o jsonpath="{.status.loadBalancer.ingress[0]['hostname','ip']}")
TELEMETRY_GATEWAY_PORT=$(kubectl get svc -n gloo-mesh gloo-telemetry-gateway -o jsonpath='{.spec.ports[?(@.name=="otlp")].port}')
TELEMETRY_GATEWAY_ADDRESS=${TELEMETRY_GATEWAY_IP}:${TELEMETRY_GATEWAY_PORT}
echo "TELEMETRY_GATEWAY_ADDRESS=${TELEMETRY_GATEWAY_ADDRESS}" >> .env

kubectl apply -f- <<EOF
apiVersion: admin.gloo.solo.io/v2
kind: Workspace
metadata:
  name: global
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
  name: global
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

kubectl apply -f- <<EOF
apiVersion: admin.gloo.solo.io/v2
kind: KubernetesCluster
metadata:
   name: ${REMOTE_CLUSTER}
   namespace: gloo-mesh
spec:
   clusterDomain: cluster.local
EOF

# Grab the root CA from the management cluster
kubectl get secret relay-root-tls-secret -n gloo-mesh -o jsonpath='{.data.ca\.crt}' | base64 -d > ${SCRIPT_DIR}/../resources/relay-root-ca.crt
kubectl get secret relay-identity-token-secret -n gloo-mesh -o jsonpath='{.data.token}' | base64 -d > ${SCRIPT_DIR}/../resources/relay-identity-token
