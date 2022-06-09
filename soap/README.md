## SOAP 


```sh
kubectl create namespace soap --context gloo
kubectl --context gloo label namespace soap istio-injection=enabled

kubectl apply -f soap/world-cities.yaml -n soap --context gloo
```