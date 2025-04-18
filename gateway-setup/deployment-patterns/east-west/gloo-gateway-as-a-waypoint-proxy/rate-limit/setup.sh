#!/bin/sh

kubectl apply -f - <<EOF
apiVersion: ratelimit.solo.io/v1alpha1
kind: RateLimitConfig
metadata:
  name: ratelimit-httpbin2
  namespace: httpbin
spec:
  raw:
    descriptors:
    - key: generic_key
      value: counter
      rateLimit:
        requestsPerUnit: 1
        unit: MINUTE
    rateLimits:
    - actions:
      - genericKey:
          descriptorValue: counter
EOF

kubectl apply -f - <<EOF
apiVersion: gateway.solo.io/v1
kind: RouteOption
metadata:
  name: httpbin2
  namespace: httpbin
spec:
  targetRefs:
  - group: gateway.networking.k8s.io
    kind: HTTPRoute
    name: httpbin2
  options:
    rateLimitConfigs:
      refs:
      - name: ratelimit-httpbin2
        namespace: httpbin
EOF

kubectl apply -f - <<EOF
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: httpbin2
  namespace: httpbin
spec:
  parentRefs:
  - name: httpbin2
    kind: Service
    group: ""
  rules:
    - matches:
      - path:
          type: PathPrefix
          value: /
      backendRefs:
       - name: httpbin2
         port: 8000
EOF

kubectl apply -f - <<EOF
apiVersion: ratelimit.solo.io/v1alpha1
kind: RateLimitConfig
metadata:
  name: ratelimit-httpbin3
  namespace: httpbin
spec:
  raw:
    setDescriptors:
      - simpleDescriptors:
          - key: organization
            value: myorg
        rateLimit:
          requestsPerUnit: 1
          unit: MINUTE
    rateLimits:
    - setActions:
      - requestHeaders:
          descriptorKey: organization
          headerName: X-Organization
EOF

kubectl apply -f - <<EOF
apiVersion: gateway.solo.io/v1
kind: RouteOption
metadata:
  name: httpbin3
  namespace: httpbin
spec:
  targetRefs:
  - group: gateway.networking.k8s.io
    kind: HTTPRoute
    name: httpbin3
  options:
    rateLimitConfigs:
      refs:
      - name: ratelimit-httpbin3
        namespace: httpbin
EOF

kubectl apply -f - <<EOF
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: httpbin3
  namespace: httpbin
spec:
  parentRefs:
  - name: httpbin3
    kind: Service
    group: ""
  rules:
    - matches:
      - path:
          type: PathPrefix
          value: /
      backendRefs:
       - name: httpbin3
         port: 8000
EOF