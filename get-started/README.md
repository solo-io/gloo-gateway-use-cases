# Get Started with Gloo Gateway
This section runs through the [Get Started](https://docs.solo.io/gateway/latest/quickstart/) documentation and vets all permutations described in the documentation.  If you want to simply instantiate a Gloo Gateway for your cluster, then run any of the installation scripts in this directory.  This will install Gloo Gateway along with httpbin and setup basic routing.

The scripts here presume you have an available cluster without Gloo Gateway installed.  See the [demo-infrastructure](https://github.com/solo-io/demo-infrastructure) repo if you need help getting started.

## Testing
Run `chainsaw test` to execute tests.

### A note about testing
Tests depend on the [netshoot](https://github.com/nicolaka/netshoot) pod to be created in the default namespace.  This allows testing ingress without the need for port-forwarding the service and has the advantage that tests will work in an air-gapped environment.  

## Cleaning up 
If you need to clean up your environment, run the uninstall.sh script.