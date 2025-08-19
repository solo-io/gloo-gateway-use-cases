#!/bin/bash

# Preflight checks
# Solo distrubution of Istio patch version
# in the format 1.x.x, with no tags
if [[ -z "${ISTIO_VERSION}" ]]; then
  echo "Please set the ISTIO_VERSION environment variable to the desired Istio version (e.g., 1.18.2)."
  exit 1
fi

if [[ -z "${GLOO_OPERATOR_VERSION}" ]]; then
  echo "Please set the GLOO_OPERATOR_VERSION environment variable to the desired Gloo Operator version (e.g., 0.1.0)."
  exit 1
fi

if [[ -z "${GLOO_MESH_LICENSE_KEY}" ]]; then
  echo "Please set the GLOO_MESH_LICENSE_KEY environment variable."
  exit 1
fi

echo "Create certs for cluster 2"
cd istio-${ISTIO_VERSION}

ISTIOCTL=${HOME}/.istioctl/bin/istioctl

mkdir -p certs
pushd certs
make -f ../tools/certs/Makefile.selfsigned.mk root-ca

make -f ../tools/certs/Makefile.selfsigned.mk cluster2-cacerts
kubectl create ns istio-system || true
kubectl create secret generic cacerts -n istio-system \
    --from-file=cluster2/ca-cert.pem \
    --from-file=cluster2/ca-key.pem \
    --from-file=cluster2/root-cert.pem \
    --from-file=cluster2/cert-chain.pem

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
  cluster: cluster2
  network: cluster2
  dataplaneMode: Ambient
  installNamespace: istio-system
  version: ${ISTIO_VERSION}
EOF

sleep 20

kubectl apply -f https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.2.1/standard-install.yaml

kubectl create namespace istio-eastwest 
${ISTIOCTL} multicluster expose --namespace istio-eastwest

sleep 20

CLUSTER2_EW_ADDRESS=$(kubectl get svc -n istio-eastwest istio-eastwest -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
echo "CLUSTER2_EW_ADDRESS=${CLUSTER2_EW_ADDRESS}" >> .env
