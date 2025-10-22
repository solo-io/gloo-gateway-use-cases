# Get Started
This section runs through the [Get Started](https://docs.solo.io/gateway/2.0.x/quickstart/) documentation and vets all permutations described in the documentation.  If you want to simply instantiate a Gloo Gateway for your cluster, then you will find each variant for kgateway and agentgateway. 

The scripts here presume you have an available cluster without Gloo Gateway installed.  See the [demo-infrastructure](https://github.com/solo-io/demo-infrastructure) repo if you need help getting started.  This has been tested successfully using docker-desktop for Kubernetes on a Mac silicon based instance.

## Testing
Run `chainsaw test` within one of the variant subfolders to both install the system and run tests.  The resulting system will be ready for further testing with Gloo Gateway after it is finished, so the tests are not idempotent.  

There are some values that are mandatory depending on the installation variant you choose.  It's best to capture your values in a yaml file and pass them into chainsaw like the following:

```
chainsaw test --values ~/.config/test-values.yaml
```

The mandatory values for this module are:
- glooGatewayLicense
- agentGatewayLicense
- glooVersion


The test scripts will pass these values to `helm`.


## Cleaning up 
If you need to clean up your environment, you can follow the steps at https://docs.solo.io/gateway/2.0.x/quickstart/#cleanup or just reset your cluster if using docker-desktop.  The cleanup.sh script in this folder will also run through the cleanup steps according to the documentation.

