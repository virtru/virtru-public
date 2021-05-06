#!/usr/bin/env bash
# This script illustrates how to deploy to GKE staging environment using mpdev
# pwd should be /your/path/to/virtru-public
# Reference: https://docs-development.preprod.virtru.com/gcp/gcr/

# Prerequisite: install Application CRD
# kubectl apply -f "https://raw.githubusercontent.com/GoogleCloudPlatform/marketplace-k8s-app-tools/master/crd/app-crd.yaml"

# Prerequisite: connect to GKE if you want to deploy there.
# gcloud container clusters get-credentials marketplace-gateway --region us-central-1 --region us-central1-a

# Authenticate gcloud with your Google account:
#   gcloud auth login
# (Follow login prompts in the web browser)
# Then apply Google auth to docker:
#   gcloud auth configure-docker

set -eu

export TAG=3.4.0;
export DEPLOYER_VERSION=3.4;
export REGISTRY=gcr.io/virtru-public/staging/gateway;
docker build --no-cache --build-arg TAG=$TAG --build-arg REGISTRY=$REGISTRY \
  -t "${REGISTRY}/deployer:${DEPLOYER_VERSION}" -f dev.Dockerfile .
docker push "${REGISTRY}/deployer:${DEPLOYER_VERSION}"

# reportingSecret:
# To actually report to the real Google ServiceControlEndpoint use "gateway-reportingsecret"
# To make sure not to bill, use "gs://cloud-marketplace-tools/reporting_secrets/fake_reporting_secret.yaml"}'

# mpdev install to install, mpdev verify to test
mpdev install --deployer="${REGISTRY}/deployer:${DEPLOYER_VERSION}" \
--parameters='{"name": "gateway", "namespace": "virtru", "gatewayHostname": "gateway-development.virtru.com", "gatewayApiTokenName": "token", "gatewayApiSecret": "mysecret", "numberOfLicenses":"10", "primaryMailingDomain":"virtru.example.com", "reportingSecret":"gs://cloud-marketplace-tools/reporting_secrets/fake_reporting_secret.yaml"}'
