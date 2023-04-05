#!/bin/bash

# exit if value for Solo Istio image is not supplied
if [[ -z "${ISTIO_REPO}" ]]; then
  echo ERROR: Specify a value for ISTIO_REPO environment variable
  echo Find the value for your Istio version at https://bit.ly/solo-istio-images
  echo The Istio images page requires user registration. Ask your Solo account executive for details.
  echo Exiting
  exit 1
fi

# exit if value for Mesh license key is not supplied
if [[ -z "${GLOO_MESH_LICENSE_KEY}" ]]; then
  echo ERROR: Specify a value for GLOO_MESH_LICENSE_KEY environment variable
  echo Ask your Solo account executive to supply one if your organization does not have one.
  echo Exiting
  exit 1
fi

# exit if value for Mesh version is not supplied
if [[ -z "${GLOO_MESH_VERSION}" ]]; then
  echo ERROR: Specify a value for GLOO_MESH_VERSION environment variable
  echo Valid values look like this: v2.0.7
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

export PATH=$HOME/.gloo-mesh/bin:$PATH

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

# update IstioOperator config with Istio image key from ISTIO_REPO environment variable
sed -i '' "s|INSERT-ISTIO-REPO-KEY-FOR-VERSION-TAG-HERE|${ISTIO_REPO}|" setup/istio/istiooperator.yaml
rc=$?
if [ $rc -ne 0 ]; then
  # Linux syntax for sed in-place replacement is slightly different
  sed -i "s|INSERT-ISTIO-REPO-KEY-FOR-VERSION-TAG-HERE|${ISTIO_REPO}|" setup/istio/istiooperator.yaml
fi

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
