#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/_tf.sh"

cd "$REPO_ROOT"
"$REPO_ROOT/scripts/public-release-check.sh"
python3 -m compileall -q services
for f in scripts/*.sh; do bash -n "$f"; done

if find "$REPO_ROOT" -path "$REPO_ROOT/.git" -prune -o -path "$REPO_ROOT/scenarios" -print -quit | grep -q .; then
  echo "ERROR: participant repository contains trainer-only scenario material" >&2
  exit 1
fi

if git log --all --name-only --format= | grep -Eq '(^|/)(scenarios/|ACCEPTANCE_TEST\.md$|TRAINING_VALUE_MAP\.md$|XDEVOPS_INTEGRATION\.md$|ENTERPRISE_READINESS(_REVIEW)?\.md$)'; then
  echo "ERROR: participant Git history contains trainer-only paths/answer material" >&2
  exit 1
fi
if grep -RIn 'imageTag: "latest"' helm/xdevops-training >/dev/null || \
   grep -RIn 'imageTag: "v1"' helm/xdevops-training >/dev/null; then
  echo "ERROR: mutable release image tag found in Helm defaults" >&2
  exit 1
fi

terraform -chdir="$TF_DIR" fmt -check -recursive
terraform -chdir="$TF_DIR" init -backend=false -input=false >/dev/null
terraform -chdir="$TF_DIR" validate

helm lint helm/xdevops-training -f helm/xdevops-training/values-stage.yaml \
  --set global.imageRegistry=example.azurecr.io --set global.imageTag=validation \
  --set networkPolicy.postgresSubnetCidr=10.42.4.0/24
helm lint helm/xdevops-training -f helm/xdevops-training/values-prod.yaml \
  --set global.imageRegistry=example.azurecr.io --set global.imageTag=validation \
  --set networkPolicy.postgresSubnetCidr=10.42.4.0/24
helm template validation-stage helm/xdevops-training -f helm/xdevops-training/values-stage.yaml \
  --set global.imageRegistry=example.azurecr.io --set global.imageTag=validation >/dev/null
helm template validation-prod helm/xdevops-training -f helm/xdevops-training/values-prod.yaml \
  --set global.imageRegistry=example.azurecr.io --set global.imageTag=validation >/dev/null

echo "Static validation passed. Azure plan/apply and live acceptance tests are still required."
