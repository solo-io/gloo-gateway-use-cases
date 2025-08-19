# Ingress to Ambient Mesh
In this section, it is assumed you have created the cluster(s) prior to testing.  For a simple setup, just use colima.

```
colima start --profile cluster1 --cpu 4 --memory 8 --kubernetes
```

For multi-cluster scenarios, there is a preflight step that creates multiple k3d clusters automatically.