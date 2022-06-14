```sh
export MGMT_CONTEXT=mgmt
export REMOTE_CONTEXT1=cluster1
export REMOTE_CONTEXT2=cluster2

export ISTIO_VERSION=1.13.4-solo
# Find ISTIO_REPO values at https://bit.ly/solo-istio-images - requires user registration
export ISTIO_REPO="insert-istio-repo-key-for-ISTIO_VERSION-here"

export GLOO_MESH_VERSION=v2.0.6

curl -sL https://run.solo.io/meshctl/install | GLOO_MESH_VERSION=${GLOO_MESH_VERSION} sh -

meshctl install \
  --kubecontext gloo \
  --license $GLOO_MESH_LICENSE_KEY \
  --version $GLOO_MESH_VERSION \
  --set mgmtClusterName=gloo

meshctl cluster register \
  --kubecontext=gloo \
  --remote-context=gloo \
  --version $GLOO_MESH_VERSION \
  gloo

```

## Install Istio

```sh
kubectl create ns istio-gateways --context gloo

istioctl install -y --context gloo -f setup/istio/istiooperator.yaml
```
## Deploy RootTrustPolicy

```sh
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
```

## Gloo Mesh Addons

```sh
kubectl --context gloo create namespace gloo-mesh-addons
kubectl --context gloo label namespace gloo-mesh-addons istio-injection=enabled

helm upgrade --install gloo-mesh-agent-addons gloo-mesh-agent/gloo-mesh-agent \
  --namespace gloo-mesh-addons \
  --kube-context=gloo \
  --set glooMeshAgent.enabled=false \
  --set rate-limiter.enabled=true \
  --set ext-auth-service.enabled=true \
  --version $GLOO_MESH_VERSION
```