#!/bin/bash

kubectl delete secret apikey -n gloo-system
kubectl delete routeoption httpbin2 -n httpbin
kubectl delete authconfig apikeys -n httpbin
kubectl delete httproute httpbin2 -n httpbin