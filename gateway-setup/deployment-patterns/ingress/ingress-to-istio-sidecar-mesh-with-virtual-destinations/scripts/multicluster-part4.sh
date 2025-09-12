#!/bin/bash

REVISION=gloo

kubectl rollout restart deployment istiod-${REVISION} -n istio-system
kubectl rollout restart deployment ratings-v1 reviews-v3 -n bookinfo