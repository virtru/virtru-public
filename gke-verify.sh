#!/usr/bin/env bash
# This script runs a Google-style verification on the chart, using mpdev
# pwd should be /your/path/to/virtru-public
# Reference: https://github.com/GoogleCloudPlatform/marketplace-k8s-app-tools/blob/master/docs/verification-integration.md#troubleshooting-verification-errors

# Prerequisite: install Application CRD
# kubectl apply -f "https://raw.githubusercontent.com/GoogleCloudPlatform/marketplace-k8s-app-tools/master/crd/app-crd.yaml"

set -eu


SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
VERSION="$(< "${SCRIPT_DIR}/VERSION" )"

export TAG="${VERSION}";
export DEPLOYER_VERSION="$(echo "${VERSION}" | cut -d'.' -f 1-2)";
export REGISTRY=gcr.io/virtru-public/staging/gateway;

printf 'Using container tag = [%s] and deployer version = [%s]\n' $TAG $DEPLOYER_VERSION

# reportingSecret:
# To actually report to the real Google ServiceControlEndpoint use "gateway-reportingsecret"
# To make sure not to bill, use "gs://cloud-marketplace-tools/reporting_secrets/fake_reporting_secret.yaml"}'

parameters=$(cat <<virtruparams 
{
  "name": "gateway",
  "namespace":
  "virtru","gatewayHostname":
  "gateway-development.virtru.com",
  "gatewayApiTokenName": "token",
  "gatewayApiSecret": "mysecret",
  "image.repository": "${REGISTRY}",
  "image.tag": "${TAG}",
  "numberOfLicenses":"10",
  "primaryMailingDomain":"virtru.example.com",
  "reportingSecret":"gs://cloud-marketplace-tools/reporting_secrets/fake_reporting_secret.yaml"
}
virtruparams
)

docker build --no-cache --build-arg TAG="${TAG}" --build-arg REGISTRY="${REGISTRY}" \
  -t "${REGISTRY}/deployer:${DEPLOYER_VERSION}" -f dev.Dockerfile "${SCRIPT_DIR}" 

docker push "${REGISTRY}/deployer:${DEPLOYER_VERSION}"

# mpdev install to install, mpdev verify to test
mpdev verify --deployer="${REGISTRY}/deployer:${DEPLOYER_VERSION}"
