#!/bin/bash

# Preflight checks
if [[ -z "${GLOO_MESH_LICENSE_KEY}" ]]; then
  echo "Please set the GLOO_MESH_LICENSE_KEY environment variable."
  exit 1
fi

if [[ -z "${GLOO_OPERATOR_VERSION}" ]]; then
  echo "Please set the GLOO_OPERATOR_VERSION environment variable."
  exit 1
fi

if [[ -z "${CLUSTER_NAME}" ]]; then
  echo "Please set the CLUSTER_NAME environment variable."
  exit 1
fi

if [[ -z "${GLOO_GATEWAY_LICENSE_KEY}" ]]; then
  echo "Please set the GLOO_GATEWAY_LICENSE_KEY environment variable."
  exit 1
fi


# Deploy Istio
echo "Deploying Istio..."
helm install gloo-operator oci://us-docker.pkg.dev/solo-public/gloo-operator-helm/gloo-operator \
--version ${GLOO_OPERATOR_VERSION} \
-n gloo-mesh \
--create-namespace \
--set manager.env.SOLO_ISTIO_LICENSE_KEY=${GLOO_GATEWAY_LICENSE_KEY}

sleep 10

kubectl apply -n gloo-mesh -f - <<EOF
apiVersion: operator.gloo.solo.io/v1
kind: ServiceMeshController
metadata:
  name: managed-istio
  labels:
    app.kubernetes.io/name: managed-istio
spec:
  # required for multicluster setups
  cluster: ${CLUSTER_NAME}
  dataplaneMode: Sidecar
  installNamespace: istio-system
  version: ${ISTIO_VERSION}
EOF

sleep 20
