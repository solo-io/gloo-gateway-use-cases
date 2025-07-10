#!/bin/bash
# Remote cluster initial setup script

if [[ -z "${GLOO_MESH_VERSION}" ]]; then
  echo "GLOO_MESH_VERSION is not set. Please set it to the desired version."
  exit 1
fi

if [[ -z "${REMOTE_CLUSTER}" ]]; then
  echo "REMOTE_CLUSTER is not set. Please set it to the name of your remote cluster."
  exit 1
fi


SCRIPT_DIR=$(dirname "$0")

source ${SCRIPT_DIR}/../.env

if [[ -z "${MGMT_SERVER_NETWORKING_ADDRESS}" ]]; then
  echo "MGMT_SERVER_NETWORKING_ADDRESS is not set. Please set it to the management server's networking address."
  exit 1
fi
if [[ -z "${TELEMETRY_GATEWAY_ADDRESS}" ]]; then
  echo "TELEMETRY_GATEWAY_ADDRESS is not set. Please set it to the telemetry gateway's address."
  exit 1
fi

# Set the context to the worker cluster
kubectl create ns httpbin
kubectl -n httpbin apply -f https://raw.githubusercontent.com/solo-io/gloo-mesh-use-cases/main/policy-demo/httpbin.yaml

# Install the Gloo Mesh CRDs
helm upgrade -i gloo-platform-crds gloo-platform/gloo-platform-crds \
 --namespace=gloo-mesh \
 --create-namespace \
 --set installEnterpriseCrds=true \
 --version=$GLOO_MESH_VERSION

# Create the Relay root secret in the worker cluster
kubectl create secret generic relay-root-tls-secret -n gloo-mesh --from-file ca.crt=${SCRIPT_DIR}/../resources/relay-root-ca.crt
rm ${SCRIPT_DIR}/../resources/relay-root-ca.crt

kubectl create secret generic relay-identity-token-secret -n gloo-mesh --from-file token=${SCRIPT_DIR}/../resources/relay-identity-token
rm ${SCRIPT_DIR}/../resources/relay-identity-token

helm upgrade -i gloo-platform gloo-platform/gloo-platform \
 --namespace gloo-mesh \
 --version $GLOO_MESH_VERSION \
 --values $SCRIPT_DIR/../resources/data-plane.yaml \
 --set common.cluster=$REMOTE_CLUSTER \
 --set glooAgent.relay.serverAddress=$MGMT_SERVER_NETWORKING_ADDRESS \
 --set telemetryCollector.config.exporters.otlp.endpoint=$TELEMETRY_GATEWAY_ADDRESS


kubectl wait --for=condition=Available=True --timeout=600s -n gloo-mesh deployment/gloo-mesh-agent

# Install Gloo Gateway Enterprise
bash ${SCRIPT_DIR}/../../../get-started/ent/helm/scripts/install-gloo-gateway.sh

# Install netshoot
kubectl apply -f- <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: netshoot
  namespace: default
spec:
  replicas: 1
  selector:
    matchLabels:
      app: netshoot
  template:
    metadata:
      labels:
        app: netshoot
    spec:
      containers:
      - name: netshoot
        image: nicolaka/netshoot
        command: ["sleep", "3600"]
EOF