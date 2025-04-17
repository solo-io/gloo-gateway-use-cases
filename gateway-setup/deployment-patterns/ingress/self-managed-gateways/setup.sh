#!/bin/bash

# First, need to check for the existence of a license key.
if [[ -z "${GLOO_GATEWAY_LICENSE_KEY}" ]]; then
  echo "Please set the GLOO_GATEWAY_LICENSE_KEY environment variable."
  exit 1
fi

GLOO_VERSION=1.18.10

# The script meat.
echo "Installing the latest Gloo CLI..."
curl -sL https://run.solo.io/gloo/install | sh
export PATH=$HOME/.gloo/bin:$PATH

# Installing Gloo Gateway Enterprise Edition
echo "Installing Kubernetes Gateway API CRDs..."
kubectl apply -f https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.2.0/standard-install.yaml
echo "Installing Gloo Gateway Enterprise Edition..."
helm repo add glooe https://storage.googleapis.com/gloo-ee-helm
helm repo update
helm install -n gloo-system gloo glooe/gloo-ee \
--create-namespace \
--set-string license_key=${GLOO_GATEWAY_LICENSE_KEY} \
--version ${GLOO_VERSION} \
-f -<< EOF
gloo:
  discovery:
    enabled: false
  gatewayProxies:
    gatewayProxy:
      disabled: true
  gloo:
    disableLeaderElection: true
  kubeGateway:
    enabled: true
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
EOF

sleep 30


# Deploy a simple app.
echo "Deploying a simple app..."
kubectl create ns httpbin
kubectl -n httpbin apply -f https://raw.githubusercontent.com/solo-io/gloo-mesh-use-cases/main/policy-demo/httpbin.yaml

sleep 30

kubectl apply -f- <<EOF
apiVersion: gateway.gloo.solo.io/v1alpha1
kind: GatewayParameters
metadata:
  name: self-managed
  namespace: gloo-system
spec:
  selfManaged: {}
EOF

kubectl apply -f- <<EOF
kind: Gateway
apiVersion: gateway.networking.k8s.io/v1
metadata:
  name: self-managed
  namespace: gloo-system
  annotations:
    gateway.gloo.solo.io/gateway-parameters-name: "self-managed"
spec:
  gatewayClassName: gloo-gateway
  listeners:
  - protocol: HTTP
    port: 80
    name: http
    allowedRoutes:
      namespaces:
        from: All
EOF

# Create a ConfigMap for the self-managed gateway
kubectl apply -f- <<EOF
apiVersion: v1
kind: ConfigMap
metadata:
  name: envoy-config
  namespace: gloo-system
  labels:
    app.kubernetes.io/instance: self-managed
    app.kubernetes.io/name: gloo-proxy-self-managed
    gateway.networking.k8s.io/gateway-name: self-managed
data: 
  envoy.yaml: |
    admin:
      address:
        socket_address: { address: 127.0.0.1, port_value: 19000 }
    node: 
      cluster: gloo-proxy-self-managed.gloo-system
      metadata:
        role: gloo-kube-gateway-api-gloo-system-gloo-system-gloo-gateway-self-managed
    static_resources:
      listeners:
      - name: read_config_listener
        address:
          socket_address: { address: 0.0.0.0, port_value: 8082 }
        filter_chains:
          - filters:
            - name: envoy.filters.network.http_connection_manager
              typed_config:
                "@type": type.googleapis.com/envoy.extensions.filters.network.http_connection_manager.v3.HttpConnectionManager
                stat_prefix: ingress_http
                codec_type: AUTO
                route_config:
                  name: main_route
                  virtual_hosts:
                    - name: local_service
                      domains: ["*"]
                      routes:
                        - match:
                            path: "/ready"
                            headers:
                              - name: ":method"
                                string_match:
                                  exact: "GET"
                          route:
                            cluster: admin_port_cluster
                http_filters:
                  - name: envoy.filters.http.router
                    typed_config:
                      "@type": type.googleapis.com/envoy.extensions.filters.http.router.v3.Router
      clusters:
        - name: xds_cluster
          alt_stat_name: xds_cluster
          connect_timeout: 5.000s
          load_assignment:
            cluster_name: xds_cluster
            endpoints:
            - lb_endpoints:
              - endpoint:
                  address:
                    socket_address:
                      address: $CONTROLLER_HOST
                      port_value: 9977
          typed_extension_protocol_options:
            envoy.extensions.upstreams.http.v3.HttpProtocolOptions:
              "@type": type.googleapis.com/envoy.extensions.upstreams.http.v3.HttpProtocolOptions
              explicit_http_config:
                http2_protocol_options: {}
          upstream_connection_options:
            tcp_keepalive:
              keepalive_time: 10
          type: STRICT_DNS
          respect_dns_ttl: true
        - name: admin_port_cluster
          connect_timeout: 5.000s
          type: STATIC
          lb_policy: ROUND_ROBIN
          load_assignment:
            cluster_name: admin_port_cluster
            endpoints:
            - lb_endpoints:
              - endpoint:
                  address:
                    socket_address:
                      address: 127.0.0.1
                      port_value: 19000
      dynamic_resources:
        ads_config:
          transport_api_version: V3
          api_type: GRPC
          rate_limit_settings: {}
          grpc_services:
          - envoy_grpc:
              cluster_name: xds_cluster
        cds_config:
          resource_api_version: V3
          ads: {}
        lds_config:
          resource_api_version: V3
          ads: {}
EOF

# Create a Gateway deployment for the self-managed gateway
kubectl apply -f- <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: self-managed-gateway
  namespace: gloo-system
  labels:
    app.kubernetes.io/instance: self-managed
    app.kubernetes.io/name: gloo-proxy-self-managed
    gateway.networking.k8s.io/gateway-name: self-managed
spec:
  progressDeadlineSeconds: 600
  replicas: 1
  revisionHistoryLimit: 10
  selector:
    matchLabels:
      app.kubernetes.io/instance: self-managed
      app.kubernetes.io/name: gloo-proxy-self-managed
      gateway.networking.k8s.io/gateway-name: self-managed
  strategy:
    rollingUpdate:
      maxSurge: 25%
      maxUnavailable: 25%
    type: RollingUpdate
  template:
    metadata:
      annotations:
        prometheus.io/path: /metrics
        prometheus.io/port: "9091"
        prometheus.io/scrape: "true"
      labels:
        app.kubernetes.io/instance: self-managed
        app.kubernetes.io/name: gloo-proxy-self-managed
        gateway.networking.k8s.io/gateway-name: self-managed
    spec:
      containers:
      - args:
        - --disable-hot-restart
        - --service-node
        - ${POD_NAME}.${POD_NAMESPACE}
        env:
        - name: POD_NAME
          valueFrom:
            fieldRef:
              fieldPath: metadata.name
        - name: POD_NAMESPACE
          valueFrom:
            fieldRef:
              apiVersion: v1
              fieldPath: metadata.namespace
        - name: ENVOY_UID
          value: "0"
        image: quay.io/solo-io/gloo-ee-envoy-wrapper:1.18.10@sha256:23dd83c30606dfe4e33a7320e47a7ae20e0d7743a26829124c14064d03a321a7
        imagePullPolicy: IfNotPresent
        name: self-managed-gateway
        ports:
        - containerPort: 80
          name: http
          protocol: TCP
        - containerPort: 9091
          name: http-monitoring
          protocol: TCP
        resources: {}
        securityContext:
          allowPrivilegeEscalation: false
          capabilities:
            add:
            - NET_BIND_SERVICE
            drop:
            - ALL
          readOnlyRootFilesystem: true
          runAsNonRoot: true
          runAsUser: 10101
        terminationMessagePath: /dev/termination-log
        terminationMessagePolicy: File
        volumeMounts:
        - mountPath: /etc/envoy
          name: envoy-config
      volumes:
        - name: envoy-config
          configMap:
            name: envoy-config
EOF


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

echo "You should be setup now.  Try testing!"