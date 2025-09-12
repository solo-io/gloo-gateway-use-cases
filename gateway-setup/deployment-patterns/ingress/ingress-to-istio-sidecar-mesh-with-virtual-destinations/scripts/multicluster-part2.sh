#!/bin/bash

kubectl apply -f - <<EOF
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