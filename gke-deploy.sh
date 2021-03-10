#!/usr/bin/env bash
# Deploy to GKE staging environment using mpdev
# pwd should be /your/path/to/virtru-public
# Reference: https://docs-development.preprod.virtru.com/gcp/gcr/

# Authenticate gcloud with your Google account:
#   gcloud auth login
# (Follow login prompts in the web browser)
# Then apply Google auth to docker:
#   gcloud auth configure-docker
set -eu

export TAG=2.16.1;
export DEPLOYER_VERSION=2.16.1;
export REGISTRY=gcr.io/virtru-public/staging/gateway;
docker build --no-cache --build-arg TAG=$TAG --build-arg REGISTRY=$REGISTRY \
  -t "${REGISTRY}/deployer:${DEPLOYER_VERSION}" -f dev.Dockerfile .
docker push "${REGISTRY}/deployer:${DEPLOYER_VERSION}"

# mpdev install to install, mpdev verify to test
mpdev install --deployer="${REGISTRY}/deployer:${DEPLOYER_VERSION}" \
--parameters='{"name": "gateway", "namespace": "virtru", "gatewayHostname": "gateway-development.virtru.com", "gatewayApiTokenName": "token", "gatewayApiSecret": "mysecret", "reportingSecret": "myReportingSecret", "imageUbbagent":"gcr.io/cloud-marketplace-tools/metering/ubbagent:latest", "licensedUsers":"10"}'