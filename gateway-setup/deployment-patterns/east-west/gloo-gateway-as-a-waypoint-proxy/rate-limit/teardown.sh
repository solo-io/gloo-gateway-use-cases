#!/bin/sh

kubectl delete ratelimitconfig ratelimit-httpbin2 ratelimit-httpbin3 -n httpbin
kubectl delete routeoption httpbin2 httpbin3 -n httpbin
kubectl delete httproutes httpbin2 httpbin3 -n httpbin