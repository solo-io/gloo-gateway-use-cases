#!/bin/bash

SCRIPT_DIR=$(dirname "$0")

kubectl delete -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/v2.12.3/manifests/install.yaml

# Execute installation script from get-started
$SCRIPT_DIR/../../get-started/uninstall.sh