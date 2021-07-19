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

cd chart/gateway
helm dependency update
cd -

if [[ "${ENVIRONMENT:-}" = 'production' ]]; then
  export REGISTRY=gcr.io/virtru-public/gateway;
  printf 'Deploying to production. Using registry [%s]\n' $REGISTRY
else
  export REGISTRY=gcr.io/virtru-public/staging/gateway;
  printf 'Deploying to staging. Using registry [%s]\n' $REGISTRY
fi

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
VERSION="$(< "${SCRIPT_DIR}/VERSION" )"

export TAG="${VERSION}";
export DEPLOYER_VERSION="$(echo "${VERSION}" | cut -d'.' -f 1-2)";

printf 'Using container tag = [%s] and deployer version = [%s]\n' $TAG $DEPLOYER_VERSION

docker build --no-cache --build-arg TAG=$TAG --build-arg REGISTRY=$REGISTRY \
  -t "${REGISTRY}/deployer:${DEPLOYER_VERSION}" -f dev.Dockerfile "${SCRIPT_DIR}"

docker push "${REGISTRY}/deployer:${DEPLOYER_VERSION}"

# reportingSecret:
# To actually report to the real Google ServiceControlEndpoint use "gateway-reportingsecret"
# To make sure not to bill, use "gs://cloud-marketplace-tools/reporting_secrets/fake_reporting_secret.yaml"}'
parameters=$(cat <<virtruparams
{
  "name": "gateway",
  "namespace": "virtru",
  "gatewayHostname": "gateway-development.virtru.com",
  "gatewayApiTokenName": "token",
  "gatewayApiSecret": "mysecret",
  "numberOfLicenses":"10",
  "primaryMailingDomain":"virtru.example.com",
  "reportingSecret":"gs://cloud-marketplace-tools/reporting_secrets/fake_reporting_secret.yaml",
  "cse.appSecrets.hmac.tokenId":"fake-token-id",
  "cse.appSecrets.hmac.tokenSecret":"fake-token-id",
  "cse.appSecrets.secretKey":"secret:fake-secret",
  "cse.appConfig.jwksAuthzIssuers":"eyAidmlydHJ1LXRlc3QiOiAiaHR0cDovL2p3dC5kZWZhdWx0LnN2Yy5jbHVzdGVyLmxvY2FsL2p3ay5qc29uIiB9Cg==",
  "cse.appConfig.jwksAuthnIssuers":"eyAidmlydHJ1LXRlc3QiOiAiaHR0cDovL2p3dC5kZWZhdWx0LnN2Yy5jbHVzdGVyLmxvY2FsL2p3ay5qc29uIiB9Cg==",
  "cse.appConfig.jwtAud":"eyJhdXRobiI6InZpcnRydS10ZXN0IiwiYXV0aHoiOiJ2aXJ0cnUtdGVzdCJ9Cg==",
  "cse.appConfig.jwtKaclsUrl":"http://cse.virtru.svc.cluster.local"
}
virtruparams
)

# mpdev install to install, mpdev verify to test
mpdev install --deployer="${REGISTRY}/deployer:${DEPLOYER_VERSION}" --parameters="${parameters}"
