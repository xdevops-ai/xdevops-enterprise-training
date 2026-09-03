#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/_tf.sh"
cd "$REPO_ROOT"

ACR_NAME="$(tf output -raw acr_name)"
TAG="${TAG:-$(git rev-parse --short=12 main)}"
PYTHON_BASE_IMAGE="${PYTHON_BASE_IMAGE:-python:3.12-slim}"
POSTGRES_BASE_IMAGE="${POSTGRES_BASE_IMAGE:-postgres:16-alpine}"
ENFORCE_PINNED_BASE_IMAGES="${ENFORCE_PINNED_BASE_IMAGES:-0}"

check_base_image() {
  local name="$1" value="$2"
  if [[ "$value" != *@sha256:* ]]; then
    if [[ "$ENFORCE_PINNED_BASE_IMAGES" == "1" ]]; then
      echo "ERROR: $name must be digest-pinned when ENFORCE_PINNED_BASE_IMAGES=1: $value" >&2
      exit 1
    fi
    echo "WARNING: $name is not digest-pinned: $value" >&2
    echo "         Use an approved image@sha256:... value for the enterprise course baseline." >&2
  fi
}

check_base_image PYTHON_BASE_IMAGE "$PYTHON_BASE_IMAGE"
check_base_image POSTGRES_BASE_IMAGE "$POSTGRES_BASE_IMAGE"

: > .training-images.tsv

build_and_lock() {
  local svc="$1" dockerfile="$2" build_arg_name="$3" build_arg_value="$4"
  local image="$svc:$TAG"

  if az acr repository show --name "$ACR_NAME" --image "$image" >/dev/null 2>&1; then
    echo "Using existing image $image"
  else
    echo "Building $image in ACR $ACR_NAME"
    az acr build \
      --registry "$ACR_NAME" \
      --image "$image" \
      --file "$dockerfile" \
      --build-arg "$build_arg_name=$build_arg_value" \
      .
  fi

  # A deployed training tag is treated as immutable. It remains readable/pullable.
  az acr repository update --name "$ACR_NAME" --image "$image" \
    --write-enabled false --delete-enabled false --output none

  local digest
  digest="$(az acr repository show --name "$ACR_NAME" --image "$image" --query digest -o tsv)"
  printf '%s\t%s\t%s\n' "$svc" "$TAG" "$digest" >> .training-images.tsv
}

for svc in customer-api orders-api payments-api inventory-api load-generator; do
  build_and_lock "$svc" "services/$svc/Dockerfile" PYTHON_BASE_IMAGE "$PYTHON_BASE_IMAGE"
done
build_and_lock db-bootstrap services/db-bootstrap/Dockerfile POSTGRES_BASE_IMAGE "$POSTGRES_BASE_IMAGE"

printf '%s\n' "$TAG" > .training-image-tag

echo "Built/verified and locked all training images with tag $TAG"
echo "Recorded tag in .training-image-tag and digests in .training-images.tsv"
