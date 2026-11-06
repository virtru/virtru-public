#!/usr/bin/env bash
#
# Annotate & Mirror Images to GHCR
#
# Bash port of the "🏷️ Annotate & Mirror Images to GHCR" GitHub Actions
# workflow. Builds/annotates the deployer image and mirrors a fixed set of
# source images into the destination registry, layering a custom annotation
# onto each.
#
# Requirements: docker (with buildx), and a login to the destination registry
# (either pre-authenticated, or via GCR_USERNAME/GCR_TOKEN env vars below).

set -euo pipefail

ANNOTATION="com.googleapis.cloudmarketplace.product.service.name=services/gateway.mp-virtru-public.appspot.com"

# Destination registry base. Must match the registry we log in to below (GHCR),
# not gcr.io — the images are pushed here. Override with the REGISTRY env var.
REGISTRY="${REGISTRY:-gcr.io/virtru-public/gateway}"

GOOGLE_DEPLOYER_VERSION="13.0.16"

# Images to annotate + mirror (workflow matrix).
MIRROR_IMAGES=(
  "gcr.io/cloud-marketplace-tools/metering/ubbagent:0.2.18"
  "containers.virtru.com/gateway:v2.80.0"
#  "containers.virtru.com/cse:v5.10.0"
  "containers.virtru.com/cks:v2.9.0"
)


# Working directory for generated Dockerfiles (defaults to current dir).
WORKDIR="${WORKDIR:-.}"

# --- Helpers -----------------------------------------------------------------

log() { printf '\n\033[1m==> %s\033[0m\n' "$*"; }

cleanup() {
  rm -f "${WORKDIR}/Dockerfile.mirror.tmp" 2>/dev/null || true
}
trap cleanup EXIT

# --- version: read VERSION file ----------------------------------------------

VERSION="$(< "${WORKDIR}/VERSION")"
log "VERSION = ${VERSION}"

DEPLOYER_VERSION="$(echo "$VERSION" | awk -F '.' '{printf "%s.%s", $1, $2}')"
log "DEPLOYER_VERSION = ${DEPLOYER_VERSION}"

# --- Set up Docker Buildx ----------------------------------------------------

log "Setting up Docker Buildx"
BUILDER="annotate-mirror-builder"
if ! docker buildx inspect "${BUILDER}" >/dev/null 2>&1; then
  docker buildx create --name "${BUILDER}" --driver docker-container --use
else
  docker buildx use "${BUILDER}"
fi
docker buildx inspect --bootstrap "${BUILDER}" >/dev/null



# --- build-deployer ----------------------------------------------------------

log "Build (annotate) and push deployer to GHCR"
docker buildx build \
  --file "${WORKDIR}/Dockerfile.deployer" \
  --build-arg "REGISTRY=${REGISTRY}" \
  --build-arg "VERSION=${VERSION}" \
  --build-arg "GOOGLE_DEPLOYER_VERSION=${GOOGLE_DEPLOYER_VERSION}" \
  --tag "${REGISTRY}/deployer:${DEPLOYER_VERSION}" \
  --annotation "${ANNOTATION}" \
  --provenance=false \
  --sbom=false \
  --push \
  --platform linux/amd64 \
  "${WORKDIR}"

# --- annotate-and-mirror -----------------------------------------------------

for image in "${MIRROR_IMAGES[@]}"; do
  log "Preparing mirror for: ${image}"

  # Dockerfile that simply re-bases on the source image so the build step can
  # layer the custom annotation onto it.
  echo "FROM ${image}" > "${WORKDIR}/Dockerfile.mirror.tmp"

  ref="${image}"

  # Strip an optional @sha256:... digest.
  [[ "${ref}" == *@* ]] && ref="${ref%@*}"

  # A tag exists only if there's a ':' in the final path segment (after the
  # last '/') -- this avoids mistaking a registry port for a tag.
  last_segment="${ref##*/}"
  if [[ "${last_segment}" == *:* ]]; then
    repository="${ref%:*}"
  else
    repository="${ref}"
  fi
  name="${repository##*/}"

  tag="${REGISTRY}/${name}:${VERSION}"

  echo "Source:      ${image}"
  echo "Destination: ${tag}"

  docker buildx build \
    --file "${WORKDIR}/Dockerfile.mirror.tmp" \
    --tag "${tag}" \
    --annotation "${ANNOTATION}" \
    --provenance=false \
    --sbom=false \
    --push \
    --platform linux/amd64 \
    "${WORKDIR}"
done

log "Done."
