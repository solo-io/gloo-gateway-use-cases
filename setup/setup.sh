#!/bin/bash

# exit if placeholder value for image / hub in istiooperator.yaml file has not been replaced
if grep -q INSERT-ISTIO-REPO-KEY-FOR-VERSION-TAG-HERE setup/istio/istiooperator.yaml; then
    echo ERROR: Replace placeholder value for \"hub\" in setup/istio/istiooperator.yaml with versioning repo key for Solo Istio images. 
    echo Find hub values for your Istio version at https://bit.ly/solo-istio-images 
    echo Istio images page requires user registration. Ask your Solo account executive for details.
    echo Exiting
    exit 1
fi

# k3d-install
k3d cluster create --wait --config setup/k3d/gloo.yaml

sleep 30

# remove existing ones if they exist
kubectl config delete-cluster gloo > /dev/null 2>&1 || true
kubectl config delete-user gloo > /dev/null 2>&1 || true
kubectl config delete-context gloo > /dev/null 2>&1 || true

kubectl config rename-context k3d-gloo gloo

# Gloo Mesh Install
curl -sL https://run.solo.io/meshctl/install | GLOO_MESH_VERSION=${GLOO_MESH_VERSION} sh -

meshctl install \
  --kubecontext gloo \
  --license $GLOO_MESH_LICENSE_KEY \
  --version $GLOO_MESH_VERSION \
  --set mgmtClusterName=gloo

sleep 10

meshctl cluster register \
  --kubecontext=gloo \
  --remote-context=gloo \
  --version $GLOO_MESH_VERSION \
  gloo

kubectl create ns istio-gateways --context gloo
istioctl install -y --context gloo -f setup/istio/istiooperator.yaml

kubectl --context gloo create namespace gloo-mesh-addons
kubectl --context gloo label namespace gloo-mesh-addons istio-injection=enabled

helm upgrade --install gloo-mesh-agent-addons gloo-mesh-agent/gloo-mesh-agent \
  --namespace gloo-mesh-addons \
  --kube-context=gloo \
  --set glooMeshAgent.enabled=false \
  --set rate-limiter.enabled=true \
  --set ext-auth-service.enabled=true \
  --version $GLOO_MESH_VERSION

cat << EOF | kubectl --context gloo apply -f -
apiVersion: admin.gloo.solo.io/v2
kind: RootTrustPolicy
metadata:
  name: root-trust-policy
  namespace: gloo-mesh
spec:
  config:
    mgmtServerCa:
      generated: {}
    autoRestartPods: true
EOF
