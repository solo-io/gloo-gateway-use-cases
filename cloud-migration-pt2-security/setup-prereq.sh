
echo '*******************************************'
echo Updating Gloo Platform Helm charts...
echo '*******************************************'
helm repo add gloo-platform https://storage.googleapis.com/gloo-platform/helm-charts
helm repo update

echo '*******************************************'
echo Establishing local k3d cluster...
echo '*******************************************'
./setup/setup.sh

echo '*******************************************'
echo Rolling out httpbin deployment...
echo '*******************************************'
kubectl apply -f cloud-migration/05-ns-httpbin.yaml --context gloo
kubectl apply -f cloud-migration/06-svc-httpbin.yaml --context gloo
echo Waiting for httpbin deployment to complete...
kubectl -n httpbin rollout status deployment httpbin

echo '*******************************************'
echo Establishing Gloo Platform workspace
kubectl apply -f cloud-migration/01-ws-opsteam.yaml --context gloo

echo '*******************************************'
echo Establishing Gloo Platform virtual gateway
kubectl apply -f cloud-migration/02-vg-httpbin.yaml --context gloo

echo '*******************************************'
echo Establishing Gloo Platform route table
kubectl apply -f cloud-migration/09-rt-httpbin-int-only.yaml --context gloo
