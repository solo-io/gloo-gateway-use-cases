#!/bin/sh

echo "*************************************************************"
echo "* This script will setup a Gloo Gateway Enterprise Edition  *"
echo "* airgap environment.                                       *"
echo "*                                                           *"
echo "* We will begin by creating a local k3d cluster with a      *"
echo "* registry which will be exposed on localhost port 5000.    *"
echo "*************************************************************"

# First, need to check for the existence of a license key.
if [[ -z "${GLOO_GATEWAY_LICENSE_KEY}" ]]; then
  echo "Please set the GLOO_GATEWAY_LICENSE_KEY environment variable."
  exit 1
fi

if [[ -z "${GLOO_VERSION}" ]]; then
  echo "Please set the GLOO_VERSION environment variable."
  exit 1
fi

registry=k3d-myregistry.localhost:5001
registry_localhost=localhost:5001

echo "Retrieving Gloo Gateway images..."
helm template glooe/gloo-ee --version $GLOO_VERSION --set-string license_key=$GLOO_GATEWAY_LICENSE_KEY | yq e '. | .. | select(has("image"))' - | grep image: | sed 's/image: //' | sed -e 's/@sha256.*//' | sed -e 's/"//g' > images.txt
#helm template glooe/gloo-ee --version $GLOO_VERSION --set-string license_key=$GLOO_GATEWAY_LICENSE_KEY | yq e '. | .. | select(has("image"))' - | grep image: | sed 's/image: //' | sed -e 's/"//g' > images.txt
cat images.txt | while read image; do 
    docker pull $image; 
done

cat images.txt | while read image; do
  src=$(echo $image | sed 's/^docker\.io\///g' | sed 's/^library\///g')
  dst=$(echo $image | awk -F/ '{ if(NF>3){ print $3"/"$4}else{if((NF>2)&&($2=="solo-io")){ print $3}else{if(NF>2){ print $2"/"$3}else{if($1=="docker.io"){ print $2}else{print $1"/"$2}}}}}' | sed 's/^library\///g')
  
  id=$(docker images --format "{{.ID}}" $src)
  echo "Tagging $id as ${registry_localhost}/$dst"
  if [[ -z "$id" ]]; then
    echo "ERROR: Image id for $src not found, skipping..."
    continue
  fi

  docker tag $id ${registry_localhost}/$dst
  docker push ${registry_localhost}/$dst
done


# Installing Gloo Gateway Enterprise Edition
echo "Installing Kubernetes Gateway API CRDs..."
kubectl apply -f https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.2.0/standard-install.yaml
echo "Installing Gloo Gateway Enterprise Edition..."
helm repo add glooe https://storage.googleapis.com/gloo-ee-helm
helm repo update
helm upgrade --install -n gloo-system gloo glooe/gloo-ee \
--create-namespace \
--set-string license_key=${GLOO_GATEWAY_LICENSE_KEY} \
--version ${GLOO_VERSION} \
-f -<< EOF
global:
  image:
    registry: ${registry}
    disableDigest: true
gloo:
  discovery:
    enabled: false
  gatewayProxies:
    gatewayProxy:
      disabled: true
  gloo:
    disableLeaderElection: true
  kubeGateway:
    enabled: true
gloo-fed:
  enabled: false
  glooFedApiserver:
    enable: false
grafana:
  defaultInstallationEnabled: false
observability:
  enabled: false
prometheus:
  enabled: false
EOF

sleep 30

# Setup an API Gateway
echo "Setting up an API Gateway..."
kubectl apply -n gloo-system -f- <<EOF
kind: Gateway
apiVersion: gateway.networking.k8s.io/v1
metadata:
  name: http
spec:
  gatewayClassName: gloo-gateway
  listeners:
  - protocol: HTTP
    port: 8080
    name: http
    allowedRoutes:
      namespaces:
        from: All
EOF

# Deploy a simple app.
echo "Deploying a simple app..."
kubectl create ns httpbin
kubectl -n httpbin apply -f https://raw.githubusercontent.com/solo-io/gloo-mesh-use-cases/main/policy-demo/httpbin.yaml

sleep 30

# Expose the app on the gateway
echo "Exposing the app on the gateway..."
kubectl apply -f- <<EOF
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: httpbin
  namespace: httpbin
  labels:
    example: httpbin-route
spec:
  parentRefs:
    - name: http
      namespace: gloo-system
  hostnames:
    - "www.example.com"
  rules:
    - backendRefs:
        - name: httpbin
          port: 8000
EOF

kubectl apply -f- <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: netshoot
  namespace: default
spec:
  replicas: 1
  selector:
    matchLabels:
      app: netshoot
  template:
    metadata:
      labels:
        app: netshoot
    spec:
      containers:
      - name: netshoot
        image: nicolaka/netshoot
        command: ["sleep", "3600"]
EOF

echo "Installation complete!"