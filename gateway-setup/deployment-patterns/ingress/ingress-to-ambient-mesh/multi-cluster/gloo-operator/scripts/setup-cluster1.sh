#!/bin/bash

# Preflight checks
# First, need to check for the existence of a license key.
if [[ -z "${GLOO_MESH_LICENSE_KEY}" ]]; then
  echo "Please set the GLOO_MESH_LICENSE_KEY environment variable."
  exit 1
fi

# Solo distrubution of Istio patch version
# in the format 1.x.x, with no tags
if [[ -z "${ISTIO_VERSION}" ]]; then
  echo "Please set the ISTIO_VERSION environment variable to the desired Istio version (e.g., 1.18.2)."
  exit 1
fi

ISTIO_IMAGE=${ISTIO_VERSION}-solo

if [[ -z "${REPO_KEY}" ]]; then
  echo "Please set the REPO_KEY environment variable."
  exit 1
fi

if [[ -z "${GLOO_OPERATOR_VERSION}" ]]; then
  echo "Please set the GLOO_OPERATOR_VERSION environment variable to the desired Gloo Operator version (e.g., 0.1.0)."
  exit 1
fi

SCRIPT_DIR=$(dirname "$0")

# Before you begin
# Execute installation script from get-started
bash $SCRIPT_DIR/../../../../../../../get-started/ent/helm/scripts/install-gloo-gateway.sh
bash $SCRIPT_DIR/../../../../../../../get-started/common/scripts/deploy-httpbin.sh
bash $SCRIPT_DIR/../../../../../../../get-started/common/scripts/setup-api-gateway.sh
bash $SCRIPT_DIR/../../../../../../../get-started/common/scripts/expose-httpbin.sh

# Step 1: Set up an ambient mesh
echo "Setting up an ambient mesh..."
echo "Installing istioctl..."
OS=$(uname | tr '[:upper:]' '[:lower:]' | sed -E 's/darwin/osx/')
ARCH=$(uname -m | sed -E 's/aarch/arm/; s/x86_64/amd64/; s/armv7l/armv7/')
echo $OS
echo $ARCH
mkdir -p ~/.istioctl/bin
curl -sSL https://storage.googleapis.com/istio-binaries-$REPO_KEY/$ISTIO_IMAGE/istioctl-$ISTIO_IMAGE-$OS-$ARCH.tar.gz | tar xzf - -C ~/.istioctl/bin
chmod +x ~/.istioctl/bin/istioctl

ISTIOCTL=${HOME}/.istioctl/bin/istioctl

echo "Creating Root of Trust..."
curl -L https://istio.io/downloadIstio | ISTIO_VERSION=${ISTIO_VERSION} sh -
cd istio-${ISTIO_VERSION}


mkdir -p certs
pushd certs
make -f ../tools/certs/Makefile.selfsigned.mk root-ca

make -f ../tools/certs/Makefile.selfsigned.mk cluster1-cacerts
kubectl create ns istio-system || true
kubectl create secret generic cacerts -n istio-system \
    --from-file=cluster1/ca-cert.pem \
    --from-file=cluster1/ca-key.pem \
    --from-file=cluster1/root-cert.pem \
    --from-file=cluster1/cert-chain.pem

cd ../..

helm install gloo-operator oci://us-docker.pkg.dev/solo-public/gloo-operator-helm/gloo-operator \
--version ${GLOO_OPERATOR_VERSION} \
-n gloo-mesh \
--create-namespace \
--set manager.env.SOLO_ISTIO_LICENSE_KEY=$GLOO_MESH_LICENSE_KEY

kubectl apply -n gloo-mesh -f -<<EOF
apiVersion: operator.gloo.solo.io/v1
kind: ServiceMeshController
metadata:
  name: managed-istio
  labels:
    app.kubernetes.io/name: managed-istio
spec:
  cluster: cluster1
  network: cluster1
  dataplaneMode: Ambient
  installNamespace: istio-system
  version: ${ISTIO_VERSION}
EOF

sleep 20

kubectl create namespace istio-eastwest 
${ISTIOCTL} multicluster expose --namespace istio-eastwest

sleep 20

CLUSTER1_EW_ADDRESS=$(kubectl get svc -n istio-eastwest istio-eastwest -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
echo "CLUSTER1_EW_ADDRESS=${CLUSTER1_EW_ADDRESS}" >> .env
