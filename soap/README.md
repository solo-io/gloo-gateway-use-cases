## SOAP  (NOT IMPLEMENTED YET)


```sh
kubectl create namespace soap --context gloo
kubectl --context gloo label namespace soap istio-injection=enabled

kubectl apply -f soap/world-cities.yaml -n soap --context gloo
```


## Gloo mesh Config

```
kubectl apply -f soap/workspace.yaml --context gloo
kubectl apply -f soap/virtual-gateway.yaml --context gloo
kubectl apply -f soap/route-table.yaml --context gloo
```


## SOAP Request

```
curl -X POST localhost:8080 -H "SOAPAction:findCity" -H "content-type:application/xml" \
-d '<?xml version="1.0" encoding="UTF-8"?>
<Envelope xmlns="http://schemas.xmlsoap.org/soap/envelope/" xmlns:soap="http://schemas.xmlsoap.org/soap/">
  <Header />
  <Body>
    <Query>
      <CityQuery>south bo</CityQuery>
    </Query>
  </Body>
</Envelope>'
```


## Apply Policy


```
kubectl apply -f soap/transformation-policy.yaml --context gloo
```

### Test

```
curl localhost:8080 -d '{"cityQuery": "south bo"}' -H "SOAPAction:findCity" -H "content-type:application/json" | jq
```