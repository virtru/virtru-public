#!/usr/bin/env bash
# This script runs a Google-style verification on the chart, using mpdev
# pwd should be /your/path/to/virtru-public
# Reference: https://github.com/GoogleCloudPlatform/marketplace-k8s-app-tools/blob/master/docs/verification-integration.md#troubleshooting-verification-errors

# Prerequisite: install Application CRD
# kubectl apply -f "https://raw.githubusercontent.com/GoogleCloudPlatform/marketplace-k8s-app-tools/master/crd/app-crd.yaml"

set -eu

export TAG=2.14.0;
export DEPLOYER_VERSION=$TAG;
export REGISTRY=gcr.io/virtru-public/staging/gateway;
docker build --no-cache --build-arg TAG=$TAG --build-arg REGISTRY=$REGISTRY \
  -t "${REGISTRY}/deployer:${DEPLOYER_VERSION}" -f dev.Dockerfile .
docker push "${REGISTRY}/deployer:${DEPLOYER_VERSION}"

# mpdev install to install, mpdev verify to test
mpdev verify --deployer="${REGISTRY}/deployer:${DEPLOYER_VERSION}"