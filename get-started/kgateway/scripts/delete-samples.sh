#!/usr/bin/env bash

kubectl delete -f https://raw.githubusercontent.com/kgateway-dev/kgateway/refs/heads/v2.0.x/examples/httpbin.yaml

kubectl delete httproute httpbin -n httpbin

kubectl delete gateway http -n gloo-system