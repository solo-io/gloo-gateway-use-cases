#!/usr/bin/env bash

kubectl apply -f https://raw.githubusercontent.com/kgateway-dev/kgateway/refs/heads/v2.0.x/examples/httpbin.yaml

sleep 15

kubectl apply -f- <<EOF
apiVersion: gloo.solo.io/v1alpha1
kind: GlooGatewayParameters
metadata:
  name: my-gw-params
  namespace: gloo-system
spec:
  kube:
    sharedExtensions:
      extauth:
        enabled: true
        container:
          image: 
            registry: gcr.io
            repository: gloo-mesh/ext-auth-service
            tag: 0.71.4
        resources:
          requests:
            cpu: 200m
            memory: 256Mi
          limits:
            cpu: 750m
            memory: 512Mi
      ratelimiter:
        enabled: true
        resources:
          requests:
            cpu: 200m
            memory: 256Mi
          limits:
            cpu: 750m
            memory: 512Mi
      glooExtCache:
        enabled: true
        resources:
          requests:
            cpu: 256m
            memory: 512Mi
          limits:
            cpu: 1000m
            memory: 2048Mi
EOF

kubectl apply -f- <<EOF
apiVersion: gateway.networking.k8s.io/v1
kind: GatewayClass
metadata:
  name: gloo-gateway-v2
spec:
  controllerName: solo.io/gloo-gateway-v2
  description: Standard class for managing Gateway API ingress traffic.
  parametersRef:
    group: gloo.solo.io
    kind: GlooGatewayParameters
    name: my-gw-params
    namespace: gloo-system
EOF

kubectl apply -f- <<EOF
kind: Gateway
apiVersion: gateway.networking.k8s.io/v1
metadata:
  name: http
  namespace: gloo-system
spec:
  gatewayClassName: gloo-gateway-v2
  listeners:
  - protocol: HTTP
    port: 8080
    name: http
    allowedRoutes:
      namespaces:
        from: All
EOF

sleep 20

kubectl apply -f- <<EOF
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: httpbin
  namespace: httpbin
spec:
  parentRefs:
    - name: http
      namespace: gloo-system
  hostnames:
    - "www.example.com"
  rules:
    - backendRefs:
        - name: httpbin
          port: 8000
EOF