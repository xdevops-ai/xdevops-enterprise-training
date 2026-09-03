#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/_tf.sh"

if [[ "${CONFIRM_DESTROY:-}" != "YES" ]]; then
  echo "Refusing to destroy. Re-run with CONFIRM_DESTROY=YES for the dedicated training environment." >&2
  exit 2
fi

RG="$(tf output -raw resource_group_name 2>/dev/null || true)"
if [[ -n "$RG" && "$RG" != rg-*-training ]]; then
  echo "Refusing to destroy unexpected resource group: $RG" >&2
  exit 1
fi

tf destroy
