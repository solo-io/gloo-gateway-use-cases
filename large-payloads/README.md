# The Elephant (Payload) in the Room: Handling Super-Sized Requests with Gloo Gateway

- Gloo Gateway: https://www.solo.io/blog/super-sized-requests-gloo-api-gateway/
- Gloo Edge: https://www.solo.io/blog/handling-super-sized-requests-with-gloo-edge/

## Deploy httpbin

```sh
kubectl create namespace httpbin --context gloo
kubectl --context gloo label namespace httpbin istio-injection=enabled

kubectl apply -f large-payloads/httpbin.yaml -n httpbin --context gloo
```

## Gloo Mesh Config

```sh
kubectl apply -f large-payloads/workspace.yaml --context gloo
kubectl apply -f large-payloads/virtual-gateway.yaml --context gloo
kubectl apply -f large-payloads/route-table.yaml --context gloo

kubectl apply -f large-payloads/transformation-policy.yaml --context gloo
```

## Generate Payloads

```sh
base64 /dev/urandom | head -c 100 > large-payloads/100b-payload.txt
base64 /dev/urandom | head -c 10000000 > large-payloads/1m-payload.txt
base64 /dev/urandom | head -c 100000000 > large-payloads/10m-payload.txt
base64 /dev/urandom | head -c 1000000000 > large-payloads/100m-payload.txt
```

## Test

```sh
curl -i -s -w "@large-payloads/curl-format.txt" -X POST -d "@large-payloads/1b-payload.txt" localhost:8080/post
curl -i -s -w "@large-payloads/curl-format.txt" -X POST -d "@large-payloads/100b-payload.txt" localhost:8080/post
curl -i -s -w "@large-payloads/curl-format.txt" -X POST -d "@large-payloads/1m-payload.txt" localhost:8080/post
curl -s -w "@large-payloads/curl-format.txt" -X POST -T "large-payloads/10m-payload.txt" localhost:8080/post -o /dev/null
curl -s -w "@large-payloads/curl-format.txt" -X POST -T "large-payloads/100m-payload.txt" localhost:8080/post -o /dev/null
```

```sh
kubectl apply -f large-payloads/transformation-policy-with-passthrough.yaml --context gloo
```
