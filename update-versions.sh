#!/bin/bash


SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

GATEWAY_VERSION='2.42.0'
CSE_VERSION='v5.6.0'
CKS_VERSION='v1.8.11'
VERSION="$(< $SCRIPT_DIR/VERSION )"

set -e

for container in GATEWAY CKS CSE; do
  lower_container=$(echo -n $container | tr '[:upper:]' '[:lower:]')
  container_version_name=$(printf '%s_VERSION' $container)
  container_version=${!container_version_name}
  container_name=$(printf 'virtru/%s:%s' $lower_container $container_version) 

  printf 'pulling %s\n' $container_name

  docker pull "${container_name}"

  if [ $container = 'GATEWAY' ]; then
    gcr_container_path='gateway'
  else
    gcr_container_path=$(printf 'gateway/%s' $lower_container)
  fi

  gcr_container_name=$(printf 'gcr.io/virtru-public/%s:%s' $gcr_container_path $VERSION )

  printf 'The gcr container: %s\n' $gcr_container_name

  docker tag $container_name $gcr_container_name

  printf 'tagging %s with %s\n' $container_name $VERSION

  docker push $gcr_container_name
done
