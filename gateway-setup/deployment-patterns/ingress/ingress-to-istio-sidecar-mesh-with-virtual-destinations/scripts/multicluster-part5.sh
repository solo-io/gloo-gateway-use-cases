#!/bin/bash

kubectl apply -n bookinfo -f- <<EOF
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

kubectl apply --context $MGMT_CONTEXT -n bookinfo -f- <<EOF
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