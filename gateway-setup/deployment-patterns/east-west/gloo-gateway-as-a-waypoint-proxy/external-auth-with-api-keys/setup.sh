#!/bin/bash

kubectl apply -f - <<EOF
apiVersion: v1
kind: Secret
type: extauth.solo.io/apikey
metadata:
  name: apikey
  namespace: gloo-system
  labels:
    team: infrastructure
stringData:
  api-key: mykey
  organization: solo.io
---
apiVersion: enterprise.gloo.solo.io/v1
kind: AuthConfig
metadata:
  name: apikeys
  namespace: httpbin
spec:
  configs:
  - apiKeyAuth:
      headerName: api-key
      labelSelector:
        team: infrastructure
      headersFromMetadataEntry:
        X-Organization:
          name: organization
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
    extauth:
      configRef:
        name: apikeys
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