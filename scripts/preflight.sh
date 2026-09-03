#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/_tf.sh"

if [[ -f "$TF_DIR/terraform.tfstate" || -f "$TF_DIR/terraform.tfstate.backup" ]]; then
  echo "ERROR: local Terraform state file detected. The shared course environment must use an encrypted, access-controlled remote backend." >&2
  exit 1
fi

for cmd in az kubectl kubelogin helm terraform python3 git; do
  command -v "$cmd" >/dev/null || { echo "Missing required command: $cmd" >&2; exit 1; }
done

RG="$(tf output -raw resource_group_name)"
AKS="$(tf output -raw aks_name)"
AKS_ID="$(tf output -raw aks_id)"
ACR_NAME="$(tf output -raw acr_name)"
NSG="$(tf output -raw postgres_nsg_name)"
RULE="$(tf output -raw postgres_nsg_rule_name)"
ADMIN_USER="$(tf output -raw postgres_administrator_login)"

printf 'Azure RG: '
az group show -n "$RG" --query name -o tsv
printf 'Training expiry: '
EXPIRY="$(az group show -n "$RG" --query 'tags.expires_on' -o tsv)"
[[ -n "$EXPIRY" ]] || { echo "ERROR: resource group is missing expires_on tag" >&2; exit 1; }
echo "$EXPIRY"
python3 - "$EXPIRY" <<'PYEXP'
from datetime import date
import sys
expiry=date.fromisoformat(sys.argv[1])
if expiry < date.today():
    raise SystemExit(f"ERROR: training environment expiry {expiry} is in the past")
PYEXP
AKS_PROVISIONING="$(az aks show -g "$RG" -n "$AKS" --query provisioningState -o tsv)"
echo "AKS provisioning: $AKS_PROVISIONING"
[[ "$AKS_PROVISIONING" == "Succeeded" ]] || { echo "ERROR: AKS provisioning state is $AKS_PROVISIONING" >&2; exit 1; }

LOCAL_ACCOUNTS_DISABLED="$(az aks show -g "$RG" -n "$AKS" --query disableLocalAccounts -o tsv)"
echo "AKS local accounts disabled: $LOCAL_ACCOUNTS_DISABLED"
[[ "$LOCAL_ACCOUNTS_DISABLED" == "true" ]] || { echo "ERROR: AKS local accounts must be disabled" >&2; exit 1; }

AKS_NETWORK_POLICY="$(az aks show -g "$RG" -n "$AKS" --query networkProfile.networkPolicy -o tsv)"
echo "AKS network policy: $AKS_NETWORK_POLICY"
[[ "${AKS_NETWORK_POLICY,,}" == "cilium" ]] || { echo "ERROR: expected Cilium network policy" >&2; exit 1; }

AKS_NETWORK_DATA_PLANE="$(az aks show -g "$RG" -n "$AKS" --query networkProfile.networkDataplane -o tsv)"
echo "AKS network data plane: $AKS_NETWORK_DATA_PLANE"
[[ "${AKS_NETWORK_DATA_PLANE,,}" == "cilium" ]] || { echo "ERROR: expected Cilium network data plane" >&2; exit 1; }

NSG_ACCESS="$(az network nsg rule show -g "$RG" --nsg-name "$NSG" -n "$RULE" --query access -o tsv)"
echo "PostgreSQL NSG rule access: $NSG_ACCESS"
[[ "$NSG_ACCESS" == "Allow" ]] || { echo "ERROR: baseline requires $RULE access=Allow" >&2; exit 1; }

PRIVATE_CLUSTER="$(az aks show -g "$RG" -n "$AKS" --query 'apiServerAccessProfile.enablePrivateCluster' -o tsv 2>/dev/null || true)"
AUTHORIZED_RANGES="$(az aks show -g "$RG" -n "$AKS" --query 'apiServerAccessProfile.authorizedIpRanges' -o tsv 2>/dev/null || true)"
echo "AKS private API server: ${PRIVATE_CLUSTER:-false}"
if [[ "${PRIVATE_CLUSTER,,}" != "true" && -z "$AUTHORIZED_RANGES" ]]; then
  if [[ "${ALLOW_PUBLIC_AKS_API_WITHOUT_CIDR:-}" == "YES" ]]; then
    echo "WARNING: explicit exception accepted: public AKS API server without authorized CIDRs."
  else
    echo "ERROR: AKS API is public without authorized CIDRs. Use a private cluster, configure authorized CIDRs, or set ALLOW_PUBLIC_AKS_API_WITHOUT_CIDR=YES only for a recorded lab exception." >&2
    exit 1
  fi
fi

echo "[preflight] Entra/Azure RBAC admin assignments"
mapfile -t ADMIN_GROUPS < <(tf output -json aks_admin_group_object_ids | python3 -c 'import json,sys; [print(x) for x in json.load(sys.stdin)]')
[[ ${#ADMIN_GROUPS[@]} -gt 0 ]] || { echo "ERROR: no AKS Entra admin group is configured" >&2; exit 1; }
for GROUP_ID in "${ADMIN_GROUPS[@]}"; do
  COUNT="$(az role assignment list --scope "$AKS_ID" --assignee-object-id "$GROUP_ID" --role "Azure Kubernetes Service RBAC Cluster Admin" --query 'length(@)' -o tsv)"
  [[ "$COUNT" != "0" ]] || { echo "ERROR: Entra admin group $GROUP_ID is missing Azure Kubernetes Service RBAC Cluster Admin at AKS scope" >&2; exit 1; }
done

az aks get-credentials --resource-group "$RG" --name "$AKS" --overwrite-existing >/dev/null

for env in stage prod; do
  ns="xdevops-training-$env"
  APP_USER="$(tf output -json postgres_application_logins | python3 -c 'import json,sys; print(json.load(sys.stdin)[sys.argv[1]])' "$env")"
  EXPECTED_DB="$(tf output -json postgres_database_names | python3 -c 'import json,sys; print(json.load(sys.stdin)[sys.argv[1]])' "$env")"
  echo "--- $ns ---"
  kubectl get ns "$ns" >/dev/null
  [[ "$(kubectl get ns "$ns" -o jsonpath='{.metadata.labels.pod-security\.kubernetes\.io/enforce}')" == "restricted" ]] || { echo "ERROR: Pod Security restricted enforcement missing on $ns" >&2; exit 1; }
  kubectl -n "$ns" get resourcequota xdevops-training-quota >/dev/null
  kubectl -n "$ns" get limitrange xdevops-training-limits >/dev/null
  kubectl -n "$ns" get networkpolicy default-deny allow-dns allow-load-generator-egress allow-load-generator-ingress allow-orders-dependencies-egress allow-orders-dependencies-ingress allow-metrics-scrape allow-postgresql >/dev/null
  kubectl -n "$ns" get pdb customer-api orders-api payments-api inventory-api >/dev/null
  kubectl -n "$ns" get secret xdevops-training-db >/dev/null
  if kubectl -n "$ns" get secret xdevops-training-db-admin >/dev/null 2>&1; then
    echo "ERROR: temporary PostgreSQL admin secret still exists in $ns" >&2
    exit 1
  fi
  ACTUAL_APP_USER="$(kubectl -n "$ns" get secret xdevops-training-db -o jsonpath='{.data.username}' | base64 -d)"
  ACTUAL_DB="$(kubectl -n "$ns" get secret xdevops-training-db -o jsonpath='{.data.database}' | base64 -d)"
  [[ "$ACTUAL_APP_USER" == "$APP_USER" ]] || { echo "Unexpected app DB user in $ns" >&2; exit 1; }
  [[ "$ACTUAL_APP_USER" != "$ADMIN_USER" ]] || { echo "Application is using the PostgreSQL administrator account" >&2; exit 1; }
  [[ "$ACTUAL_DB" == "$EXPECTED_DB" ]] || { echo "Unexpected database name in $ns: $ACTUAL_DB" >&2; exit 1; }

  for d in customer-api orders-api payments-api inventory-api load-generator; do
    kubectl -n "$ns" rollout status "deployment/$d" --timeout=120s
  done
  kubectl -n "$ns" exec deployment/load-generator -- python -c 'import urllib.request; urllib.request.urlopen("http://customer-api/health", timeout=5).read()' >/dev/null
  echo "Application health: OK"
done

echo "[preflight] ACR image immutability"
if [[ -f "$REPO_ROOT/.training-image-tag" ]]; then
  TAG="$(tr -d '\r\n' < "$REPO_ROOT/.training-image-tag")"
  for IMAGE in customer-api orders-api payments-api inventory-api load-generator db-bootstrap; do
    WRITE_ENABLED="$(az acr repository show --name "$ACR_NAME" --image "$IMAGE:$TAG" --query 'changeableAttributes.writeEnabled' -o tsv)"
    DELETE_ENABLED="$(az acr repository show --name "$ACR_NAME" --image "$IMAGE:$TAG" --query 'changeableAttributes.deleteEnabled' -o tsv)"
    [[ "$WRITE_ENABLED" == "false" && "$DELETE_ENABLED" == "false" ]] || { echo "ERROR: $IMAGE:$TAG is not locked in ACR" >&2; exit 1; }
  done
else
  echo "ERROR: .training-image-tag is missing; build the course images before preflight" >&2
  exit 1
fi

cat <<'GATES'

Manual XDevOps enterprise gates:
  [ ] Azure endpoint is scoped to the dedicated training resource group/subscription boundary.
  [ ] Kubernetes endpoint resolves only the intended AKS training cluster and policy scope.
  [ ] Prometheus endpoint sees training_http_requests_total and training_db_connection_failures_total.
  [ ] Loki endpoint can filter by namespace/service/environment and find structured customer-api events.
  [ ] Repository and runbooks are indexed with the intended tenant/ACL scope.
  [ ] !ontology list is reachable.
  [ ] !kg can show nsg-postgres-training.
  [ ] A controlled !azure NSG update creates materialized KG history/provenance.
  [ ] Operator mutation denial and approver exact-operation HITL have been tested.
  [ ] Secret/DLP negative-control behavior has been tested with synthetic data only.
GATES
