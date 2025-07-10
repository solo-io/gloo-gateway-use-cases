#!/bin/bash

# Create a Gateway in the management cluster
kubectl apply -f- <<EOF
apiVersion: gateway.networking.k8s.io/v1
kind: Gateway
metadata:
  name: distributed-gateway
  namespace: gloo-mesh
  labels:
    example: config-distro
  annotations:
    gloo.solo.io/distribute-to: "*/gloo-system"
spec:
  gatewayClassName: gloo-gateway-distribute
  listeners:
  - protocol: HTTP
    port: 8080
    hostname: mydomain.com
    name: http
    allowedRoutes:
      namespaces:
        from: All
EOF

kubectl apply -f- <<EOF
apiVersion: gloo.solo.io/v1
kind: Upstream
metadata:
  name: httpbin
  namespace: gloo-mesh
  labels:
    example: config-distro
  annotations:
    gloo.solo.io/distribute-to: "*/httpbin"
spec:
  kube:
    serviceName: httpbin
    serviceNamespace: httpbin
    servicePort: 8000
EOF

kubectl apply -f- <<EOF
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: httpbin-mydomain
  namespace: gloo-mesh
  labels:
    example: config-distro
  annotations:
    gloo.solo.io/distribute-to: "*/httpbin"
spec:
  parentRefs:
    - name: distributed-gateway
      namespace: gloo-system
  rules:
    - backendRefs:
      - name: httpbin
        kind: Upstream
        group: gloo.solo.io
EOF

sleep 20