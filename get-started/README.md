# Get Started with Gloo Gateway
This section runs through the [Get Started](https://docs.solo.io/gateway/latest/quickstart/) documentation and vets all permutations described in the documentation.  If you want to simply instantiate a Gloo Gateway for your cluster, then you will find each variant for Enterprise and OSS installation.  This will install Gloo Gateway along with httpbin and setup basic routing.

The scripts here presume you have an available cluster without Gloo Gateway installed.  See the [demo-infrastructure](https://github.com/solo-io/demo-infrastructure) repo if you need help getting started.  This has been tested successfully using docker-desktop for Kubernetes on a Mac silicon based instance.

## Testing
Run `chainsaw test` within one of the variant subfolders to both install the system and run tests.  The resulting system will be ready for further testing with Gloo Gateway after it is finished, so the tests are not idempotent.  

There are some values that are mandatory depending on the installation variant you choose.  It's best to capture your values in a yaml file and pass them into chainsaw like the following:

```
chainsaw test --values ~/.config/test-values.yaml
```

The two mandatory values for this module are:
- glooLicense
- glooVersion

The test scripts will pass these values to either the `glooctl` cli or `helm`.

Additionally, you need to provide an adequate timeout vale for execution of the script or chainsaw may prematurely abort your test.  You can pass in the execution timeout like the following:

```
chainsaw test --values ~/.config/test-values.yaml --exec-timeout 60s
```

### A note about testing
Tests depend on the [netshoot](https://github.com/nicolaka/netshoot) pod to be created in the default namespace.  This allows testing ingress without the need for port-forwarding the service and has the advantage that tests will work in an air-gapped environment.  Note that the install scripts in this directory will install netshoot for you.

## Cleaning up 
If you need to clean up your environment, you can follow the steps at https://docs.solo.io/gateway/latest/quickstart/#cleanup or just reset your cluster if using docker-desktop.  The uninstall.sh script in this folder will also run through the cleanup steps according to the documentation.

## Script architecture
Each installation sub-variant (Enterprise or OSS with cli or helm) contains a single `install-gloo-gateway.sh` script.  The rest of the instructions are common across all variants, so these scripts are in the `common/scripts` folder.  Since chainsaw works with relative path, you can reference these from other tests to combine deterministic tests.