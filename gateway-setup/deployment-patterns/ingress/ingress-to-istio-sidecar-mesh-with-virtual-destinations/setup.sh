#!/bin/bash

# Variables
GLOO_MESH_VERSION=2.7.1
MGMT_CLUSTER=mgmt
REMOTE_CLUSTER1=cluster1
REMOTE_CLUSTER2=cluster2
MGMT_CONTEXT=mgmt
REMOTE_CONTEXT1=cluster1
REMOTE_CONTEXT2=cluster2
ISTIO_VERSION=1.23.5
GLOO_VERSION=1.18.10

if [[ -z "${GLOO_MESH_LICENSE_KEY}" ]]; then
  echo "Please set the GLOO_MESH_LICENSE_KEY environment variable."
  exit 1
fi

if [[ -z "${REPO}" ]]; then
  echo "Please set the REPO environment variable. See https://support.solo.io/hc/en-us/articles/4414409064596-Istio-images-built-by-Solo-io for more info."
  exit 1
fi

if [[ -z "${GLOO_GATEWAY_LICENSE_KEY}" ]]; then
  echo "Please set the GLOO_GATEWAY_LICENSE_KEY environment variable."
  exit 1
fi

# Before you begin
# Install meshctl
echo "Installing meshctl..."
curl -sL https://run.solo.io/meshctl/install | GLOO_MESH_VERSION=v${GLOO_MESH_VERSION} sh -
export PATH=$PWD/meshctl/bin:$PATH


# Install the Gloo Mesh management plane
echo "Installing Gloo Mesh management plane..."
meshctl install --profiles mgmt-server \
--kubecontext ${MGMT_CONTEXT} \
--set common.cluster=${MGMT_CLUSTER} \
--set licensing.glooMeshLicenseKey=${GLOO_MESH_LICENSE_KEY} 

sleep 20

TELEMETRY_GATEWAY_IP=$(kubectl get svc -n gloo-mesh gloo-telemetry-gateway --context $MGMT_CONTEXT -o jsonpath="{.status.loadBalancer.ingress[0]['hostname','ip']}")
TELEMETRY_GATEWAY_PORT=$(kubectl get svc -n gloo-mesh gloo-telemetry-gateway --context $MGMT_CONTEXT -o jsonpath='{.spec.ports[?(@.name=="otlp")].port}')
TELEMETRY_GATEWAY_ADDRESS=${TELEMETRY_GATEWAY_IP}:${TELEMETRY_GATEWAY_PORT}
echo "Telemetry Gateway Address: ${TELEMETRY_GATEWAY_ADDRESS}"

kubectl apply --context $MGMT_CONTEXT -f- <<EOF
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
--kubecontext $MGMT_CONTEXT \
--remote-context $REMOTE_CONTEXT1 \
--profiles agent,ratelimit,extauth \
--telemetry-server-address $TELEMETRY_GATEWAY_ADDRESS

meshctl cluster register $REMOTE_CLUSTER2 \
--kubecontext $MGMT_CONTEXT \
--remote-context $REMOTE_CONTEXT2 \
--profiles agent,ratelimit,extauth \
--telemetry-server-address $TELEMETRY_GATEWAY_ADDRESS

sleep 30

# Deploy Istio
echo "Deploying Istio..."

helm repo add istio https://istio-release.storage.googleapis.com/charts
helm repo update
for context in ${REMOTE_CONTEXT1} ${REMOTE_CONTEXT2}; do
  helm upgrade --install istio-base istio/base \
  --namespace istio-system \
  --create-namespace \
  --version ${ISTIO_VERSION} \
  --kube-context ${context} \
  --set defaultRevison=main

  helm upgrade --install istiod istio/istiod \
  --namespace istio-system \
  --version $ISTIO_VERSION \
  --kube-context ${context} \
  --set global.hub=${REPO} \
  --set global.tag="${ISTIO_VERSION}-solo" \
  --set revision=main \
  --set "global.meshID=mesh" \
  --set "global.multiCluster.clusterName=${context}" \
  --set "meshConfig.trustDomain=${context}" \
  --set "env.PILOT_ENABLE_K8S_SELECT_WORKLOAD_ENTRIES=false" \
  --set "env.PILOT_SKIP_VALIDATE_TRUST_DOMAIN=true" \
  --set license.value=${GLOO_MESH_LICENSE_KEY} 
done

sleep 60

# Deploy Bookinfo
echo "Deploying Bookinfo..."
REVISION=$(kubectl get pod -L app=istiod -n istio-system -o jsonpath='{.items[0].metadata.labels.istio\.io/rev}')
echo ${REVISION}

kubectl create ns bookinfo --context ${REMOTE_CONTEXT1}
kubectl label ns bookinfo istio.io/rev=${REVISION} --overwrite --context ${REMOTE_CONTEXT1}
kubectl create ns bookinfo --context ${REMOTE_CONTEXT2}
kubectl label ns bookinfo istio.io/rev=${REVISION} --overwrite --context ${REMOTE_CONTEXT2}

# deploy bookinfo application components for all versions less than v3
kubectl -n bookinfo apply -f https://raw.githubusercontent.com/istio/istio/1.24.2/samples/bookinfo/platform/kube/bookinfo.yaml -l 'app,version notin (v3)' --context ${REMOTE_CONTEXT1}
# deploy an updated product page with extra container utilities such as 'curl' and 'netcat'
kubectl -n bookinfo apply -f https://raw.githubusercontent.com/solo-io/gloo-mesh-use-cases/main/policy-demo/productpage-with-curl.yaml --context ${REMOTE_CONTEXT1}
# deploy all bookinfo service accounts
kubectl -n bookinfo apply -f https://raw.githubusercontent.com/istio/istio/1.24.2/samples/bookinfo/platform/kube/bookinfo.yaml -l 'account' --context ${REMOTE_CONTEXT1}

# deploy reviews and ratings services
kubectl -n bookinfo apply -f https://raw.githubusercontent.com/istio/istio/1.24.2/samples/bookinfo/platform/kube/bookinfo.yaml -l 'service in (reviews)' --context ${REMOTE_CONTEXT2}
# deploy reviews-v3
kubectl -n bookinfo apply -f https://raw.githubusercontent.com/istio/istio/1.24.2/samples/bookinfo/platform/kube/bookinfo.yaml -l 'app in (reviews),version in (v3)' --context ${REMOTE_CONTEXT2}
# deploy ratings
kubectl -n bookinfo apply -f https://raw.githubusercontent.com/istio/istio/1.24.2/samples/bookinfo/platform/kube/bookinfo.yaml -l 'app in (ratings)' --context ${REMOTE_CONTEXT2}
# deploy reviews and ratings service accounts
kubectl -n bookinfo apply -f https://raw.githubusercontent.com/istio/istio/1.24.2/samples/bookinfo/platform/kube/bookinfo.yaml -l 'account in (reviews, ratings)' --context ${REMOTE_CONTEXT2}

sleep 30

# Setup multicluster routing
echo "Setting up multicluster routing..."
helm upgrade --install istio-eastwestgateway istio/gateway \
--version ${ISTIO_VERSION} \
--namespace istio-eastwest \
--create-namespace \
--kube-context ${REMOTE_CONTEXT1} \
--wait \
-f - <<EOF
revision: main
global:
  hub: ${REPO}
  tag: ${ISTIO_VERSION}-solo
  network: ${REMOTE_CLUSTER1}
  multiCluster:
    clusterName: ${REMOTE_CLUSTER1}
name: istio-eastwestgateway
labels:
  app: istio-eastwestgateway
  istio: eastwestgateway
  revision: main
  topology.istio.io/network: ${REMOTE_CLUSTER1}
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

helm upgrade --install istio-eastwestgateway istio/gateway \
--version ${ISTIO_VERSION} \
--namespace istio-eastwest \
--create-namespace \
--kube-context ${REMOTE_CONTEXT2} \
--wait \
-f - <<EOF
revision: main
global:
  hub: ${REPO}
  tag: ${ISTIO_VERSION}-solo
  network: ${REMOTE_CLUSTER2}
  multiCluster:
    clusterName: ${REMOTE_CLUSTER2}
name: istio-eastwestgateway
labels:
  app: istio-eastwestgateway
  istio: eastwestgateway
  revision: main
  topology.istio.io/network: ${REMOTE_CLUSTER2}
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

sleep 30

kubectl apply --context $MGMT_CONTEXT -f - <<EOF
apiVersion: admin.gloo.solo.io/v2
kind: RootTrustPolicy
metadata:
  name: root-trust
  namespace: gloo-mesh
spec:
  config:
    mgmtServerCa:
      generated: {}
EOF

sleep 20

kubectl rollout restart deployment istiod-main -n istio-system --context ${REMOTE_CONTEXT1}
kubectl rollout restart deployment istiod-main -n istio-system --context ${REMOTE_CONTEXT2}
kubectl rollout restart deployment details-v1 productpage-v1 ratings-v1 reviews-v1 reviews-v2 -n bookinfo --context ${REMOTE_CONTEXT1}
kubectl rollout restart deployment ratings-v1 reviews-v3 -n bookinfo --context ${REMOTE_CONTEXT2}
kubectl rollout restart deployment httpbin -n httpbin --context ${REMOTE_CONTEXT1}
#kubectl rollout restart deployment helloworld-v1 helloworld-v2 -n helloworld --context ${REMOTE_CONTEXT1}
#kubectl rollout restart deployment helloworld-v3 helloworld-v4 -n helloworld --context ${REMOTE_CONTEXT2}

kubectl apply --context $REMOTE_CLUSTER1 -n bookinfo -f- <<EOF
apiVersion: networking.gloo.solo.io/v2
kind: VirtualDestination
metadata:
  name: reviews-vd
  namespace: bookinfo
spec:
  hosts:
  # Arbitrary, internal-only hostname assigned to the endpoint
  - reviews.mesh.internal.com
  ports:
  - number: 9080
    protocol: HTTP
  services:
    - labels:
        app: reviews
EOF

kubectl apply --context $REMOTE_CLUSTER1 -n bookinfo -f- <<EOF
apiVersion: networking.gloo.solo.io/v2
kind: RouteTable
metadata:
  name: bookinfo-east-west
  namespace: bookinfo
spec:
  hosts:
    - 'reviews.bookinfo.svc.cluster.local'
  workloadSelectors:
    - selector:
        labels:
          app: productpage
  http:
    - name: reviews
      matchers:
      - uri:
          prefix: /reviews
      forwardTo:
        destinations:
          - ref:
              name: reviews-vd
            kind: VIRTUAL_DESTINATION
            port:
              number: 9080
      labels:
        route: reviews
EOF

# Step 2: Install Gloo Gateway
echo "Installing Gloo Gateway..."
kubectl apply -f https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.2.0/experimental-install.yaml --context $REMOTE_CONTEXT1

helm repo add glooe https://storage.googleapis.com/gloo-ee-helm
helm repo update

ISTIOD=$(kubectl get svc -n istio-system --context ${REMOTE_CONTEXT1} -o jsonpath='{.items[0].metadata.name}')

helm install -n gloo-system gloo-gateway glooe/gloo-ee \
--kube-context $REMOTE_CONTEXT1 \
--create-namespace \
--version $GLOO_VERSION \
--set-string license_key=$GLOO_GATEWAY_LICENSE_KEY \
-f -<<EOF
gloo:
  discovery:
    enabled: false
  gatewayProxies:
    gatewayProxy:
      disabled: true
  kubeGateway:
    enabled: true
    gatewayParameters:
      glooGateway:
        istio:
          istioProxyContainer:
            istioDiscoveryAddress: ${ISTIOD}.istio-system.svc:15012
            istioMetaClusterId: ${REMOTE_CLUSTER1}
            istioMetaMeshId: ${REMOTE_CLUSTER1} 
  gloo:
    disableLeaderElection: true
gloo-fed:
  enabled: false
  glooFedApiserver:
    enable: false
grafana:
  defaultInstallationEnabled: false
observability:
  enabled: false
prometheus:
  enabled: false
global:
  istioSDS:
    enabled: true
  istioIntegration:
    enabled: true
    enableAutoMtls: true
EOF

sleep 30

# Step 3: Create a gateway proxy
echo "Creating a gateway proxy..."
kubectl apply --context $REMOTE_CONTEXT1 -n gloo-system -f- <<EOF
kind: Gateway
apiVersion: gateway.networking.k8s.io/v1
metadata:
  name: http
spec:
  gatewayClassName: gloo-gateway
  listeners:
  - protocol: HTTP
    port: 8080
    name: http
    allowedRoutes:
      namespaces:
        from: All
EOF

# Step 4: Expose the product page app
echo "Exposing the product page app..."
kubectl apply --context $REMOTE_CONTEXT1 -f - <<EOF
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: productpage
  namespace: bookinfo
spec:
  parentRefs:
    - name: http
      namespace: gloo-system
  rules:
    - matches:
      - path:
          type: Exact
          value: /productpage
      - path:
          type: PathPrefix
          value: /static
      backendRefs:
        - name: productpage
          port: 9080
          namespace: bookinfo
EOF

# Step 5: Route to a Virtual Destination
echo "Routing to a Virtual Destination..."
kubectl apply --context $REMOTE_CONTEXT1 -f - <<EOF
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: reviews
  namespace: gloo-system
spec:
  parentRefs:
    - name: http
      namespace: gloo-system
  rules:
    - matches:
      - path:
          type: PathPrefix
          value: /reviews
      backendRefs:
        - name: reviews.mesh.internal.com
          port: 9080
          kind: Hostname
          group: networking.istio.io
EOF

kubectl apply --context $REMOTE_CONTEXT1 -f- <<EOF
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

echo "Setting up access logging..."
kubectl apply --context $REMOTE_CONTEXT1 -f- <<EOF
apiVersion: gateway.solo.io/v1
kind: ListenerOption
metadata:
  name: access-logs
  namespace: gloo-system
spec:
  targetRefs:
  - group: gateway.networking.k8s.io
    kind: Gateway
    name: http
  options:
    accessLoggingService:
      accessLog:
      - fileSink:
          path: /dev/stdout
          jsonFormat:
              start_time: "%START_TIME%"
              method: "%REQ(X-ENVOY-ORIGINAL-METHOD?:METHOD)%"
              path: "%REQ(X-ENVOY-ORIGINAL-PATH?:PATH)%"
              protocol: "%PROTOCOL%"
              response_code: "%RESPONSE_CODE%"
              response_flags: "%RESPONSE_FLAGS%"
              bytes_received: "%BYTES_RECEIVED%"
              bytes_sent: "%BYTES_SENT%"
              total_duration: "%DURATION%"
              resp_upstream_service_time: "%RESP(X-ENVOY-UPSTREAM-SERVICE-TIME)%"
              req_x_forwarded_for: "%REQ(X-FORWARDED-FOR)%"
              user_agent: "%REQ(USER-AGENT)%"
              request_id: "%REQ(X-REQUEST-ID)%"
              authority: "%REQ(:AUTHORITY)%"
              upstreamHost: "%UPSTREAM_HOST%"
              upstreamCluster: "%UPSTREAM_CLUSTER%"
EOF

echo "Setup complete.  Run tests via 'chainsaw test'"