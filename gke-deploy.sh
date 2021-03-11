#!/usr/bin/env bash
# Deploy to GKE staging environment using mpdev
# pwd should be /your/path/to/virtru-public
# Reference: https://docs-development.preprod.virtru.com/gcp/gcr/

# Prerequisite: install Application CRD?
# kubectl apply -f "https://raw.githubusercontent.com/GoogleCloudPlatform/marketplace-k8s-app-tools/master/crd/app-crd.yaml"

# Prerequisite: connect to GKE if you want to deploy there.
# gcloud container clusters get-credentials marketplace-gateway --region us-central-1 --region us-central1-a


# Authenticate gcloud with your Google account:
#   gcloud auth login
# (Follow login prompts in the web browser)
# Then apply Google auth to docker:
#   gcloud auth configure-docker
set -eu

export TAG=2.16.0-3;
export DEPLOYER_VERSION=$TAG;
export REGISTRY=gcr.io/virtru-public/staging/gateway;
docker build --no-cache --build-arg TAG=$TAG --build-arg REGISTRY=$REGISTRY \
  -t "${REGISTRY}/deployer:${DEPLOYER_VERSION}" -f dev.Dockerfile .
docker push "${REGISTRY}/deployer:${DEPLOYER_VERSION}"

# mpdev install to install, mpdev verify to test
mpdev install --deployer="${REGISTRY}/deployer:${DEPLOYER_VERSION}" \
--parameters='{"name": "gateway", "namespace": "virtru", "gatewayHostname": "gateway-development.virtru.com", "gatewayApiTokenName": "token", "gatewayApiSecret": "mysecret", "licensedUsers":"10", "primaryMailingDomain":"example.com", "reportingSecret":"gs://cloud-marketplace-tools/reporting_secrets/fake_reporting_secret.yaml"}'

#kubectl logs -f job/gateway-deployer
