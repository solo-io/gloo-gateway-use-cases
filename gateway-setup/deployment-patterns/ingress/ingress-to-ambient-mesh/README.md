# Ingress to Ambient Mesh
In this section, it is assumed you have created the cluster(s) prior to testing.  For a simple setup, just use colima.

```
colima start --profile cluster1 --cpu 4 --memory 8 --kubernetes
```

You can start multiple clusters this way so long as you have enough resources available.  In single cluster scenarios, you can expose the load balancer with the `--network-address` option.  However, the tests do not require this as they will use netshoot installed inside the cluster to test.