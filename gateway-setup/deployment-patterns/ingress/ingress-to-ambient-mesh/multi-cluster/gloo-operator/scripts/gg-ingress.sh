#!/bin/bash

if [[ -z "${GLOO_VERSION}" ]]; then
  echo "Please set the GLOO_VERSION environment variable."
  exit 1
fi

if [[ -z "${GLOO_GATEWAY_LICENSE_KEY}" ]]; then
  echo "Please set the GLOO_GATEWAY_LICENSE_KEY environment variable."
  exit 1
fi

SCRIPT_DIR=$(dirname "$0")

helm upgrade -n gloo-system gloo glooe/gloo-ee \
--version $GLOO_VERSION \
--set-string license_key=$GLOO_GATEWAY_LICENSE_KEY \
-f $SCRIPT_DIR/../resources/gg-values.yaml

kubectl label ns gloo-system istio.io/dataplane-mode=ambient

kubectl apply -f- <<EOF
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: productpage
  namespace: gloo-system
spec:
  parentRefs:
    - name: http
      namespace: gloo-system
  rules:
    - matches:
      - path:
          type: PathPrefix
          value: /productpage
      backendRefs:
        - name: productpage.bookinfo.mesh.internal
          port: 9080
          kind: Hostname
          group: networking.istio.io
EOF
