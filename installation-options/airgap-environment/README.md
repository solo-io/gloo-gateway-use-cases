# Airgap Environment Tests
For these tests, you will need to have a local docker registry running.  You only have to create this once as the script below will set up a registry that will be started each time your local docker environment starts up.  Look at your local containers to see if you have a kind-registry running on port 5000.  If not, then run the script below.

`./create-registry.sh`

This registry will then be used to simulate an airgapped installation.