#!/bin/bash

REVISION=gloo

kubectl rollout restart deployment istiod-${REVISION} -n istio-system
kubectl rollout restart deployment details-v1 productpage-v1 ratings-v1 reviews-v1 reviews-v2 -n bookinfo