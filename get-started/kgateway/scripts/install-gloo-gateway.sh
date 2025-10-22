#!/bin/bash

if [ -z "$GLOO_VERSION" ]; then
    echo "GLOO_VERSION is not set. Please set it to the desired version."
    exit 1
fi

if [ -z "$GLOO_GATEWAY_LICENSE_KEY" ]; then
    echo "GLOO_GATEWAY_LICENSE_KEY is not set. Please set it to the desired license key."
    exit 1
fi

kubectl apply -f https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.4.0/standard-install.yaml

helm upgrade -i gloo-gateway-crds oci://us-docker.pkg.dev/solo-public/gloo-gateway/charts/gloo-gateway-crds \
--create-namespace \
--namespace gloo-system \
--version $GLOO_VERSION

helm upgrade -i gloo-gateway oci://us-docker.pkg.dev/solo-public/gloo-gateway/charts/gloo-gateway \
-n gloo-system \
--version $GLOO_VERSION \
--set licensing.glooGatewayLicenseKey=$GLOO_GATEWAY_LICENSE_KEY

sleep 20