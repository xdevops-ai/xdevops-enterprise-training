#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/_tf.sh"

ENVIRONMENT="${1:-}"
if [[ "$ENVIRONMENT" != "prod" && "$ENVIRONMENT" != "stage" ]]; then
  echo "Usage: $0 <prod|stage>" >&2
  exit 2
fi

RG="$(tf output -raw resource_group_name)"
AKS="$(tf output -raw aks_name)"
ACR="$(tf output -raw acr_login_server)"
DB_HOST="$(tf output -raw postgres_fqdn)"
DB_NAME="$(tf output -json postgres_database_names | python3 -c 'import json,sys; print(json.load(sys.stdin)[sys.argv[1]])' "$ENVIRONMENT")"
DB_ADMIN_USER="$(tf output -raw postgres_administrator_login)"
DB_ADMIN_PASSWORD="$(tf output -raw postgres_administrator_password)"
DB_APP_USER="$(tf output -json postgres_application_logins | python3 -c 'import json,sys; print(json.load(sys.stdin)[sys.argv[1]])' "$ENVIRONMENT")"
DB_APP_PASSWORD="$(tf output -json postgres_application_passwords | python3 -c 'import json,sys; print(json.load(sys.stdin)[sys.argv[1]])' "$ENVIRONMENT")"
if [[ -n "${TAG:-}" ]]; then
  TAG="$TAG"
elif [[ -f "$REPO_ROOT/.training-image-tag" ]]; then
  TAG="$(tr -d '\r\n' < "$REPO_ROOT/.training-image-tag")"
else
  TAG="$(git -C "$REPO_ROOT" rev-parse --short=12 main)"
fi
NS="xdevops-training-$ENVIRONMENT"
RELEASE="xdevops-training-$ENVIRONMENT"

for IMAGE in customer-api orders-api payments-api inventory-api load-generator db-bootstrap; do
  az acr repository show --name "$(tf output -raw acr_name)" --image "$IMAGE:$TAG" >/dev/null 2>&1 || {
    echo "ERROR: required image $IMAGE:$TAG is not present in ACR. Run scripts/build-images.sh first." >&2
    exit 1
  }
done

az aks get-credentials --resource-group "$RG" --name "$AKS" --overwrite-existing >/dev/null
kubectl create namespace "$NS" --dry-run=client -o yaml | kubectl apply -f - >/dev/null
kubectl label namespace "$NS" \
  environment="$ENVIRONMENT" \
  app.kubernetes.io/part-of=xdevops-training \
  pod-security.kubernetes.io/enforce=restricted \
  pod-security.kubernetes.io/audit=restricted \
  pod-security.kubernetes.io/warn=restricted \
  --overwrite >/dev/null

cleanup_admin_secret() {
  kubectl -n "$NS" delete secret xdevops-training-db-admin --ignore-not-found >/dev/null 2>&1 || true
}
trap cleanup_admin_secret EXIT

# Create Secrets through stdin so secret values are not placed in kubectl command arguments.
export DB_HOST DB_NAME DB_ADMIN_USER DB_ADMIN_PASSWORD DB_APP_USER DB_APP_PASSWORD NS
python3 <<'PYSECRET' | kubectl apply -f - >/dev/null
import base64, json, os

def b64(value: str) -> str:
    return base64.b64encode(value.encode()).decode()

common = {
    "host": b64(os.environ["DB_HOST"]),
    "database": b64(os.environ["DB_NAME"]),
}
objects = [
    {
        "apiVersion": "v1",
        "kind": "Secret",
        "metadata": {"name": "xdevops-training-db", "namespace": os.environ["NS"]},
        "type": "Opaque",
        "data": {
            **common,
            "username": b64(os.environ["DB_APP_USER"]),
            "password": b64(os.environ["DB_APP_PASSWORD"]),
        },
    },
    {
        "apiVersion": "v1",
        "kind": "Secret",
        "metadata": {"name": "xdevops-training-db-admin", "namespace": os.environ["NS"]},
        "type": "Opaque",
        "data": {
            **common,
            "username": b64(os.environ["DB_ADMIN_USER"]),
            "password": b64(os.environ["DB_ADMIN_PASSWORD"]),
            "app-username": b64(os.environ["DB_APP_USER"]),
            "app-password": b64(os.environ["DB_APP_PASSWORD"]),
        },
    },
]
print(json.dumps({"apiVersion": "v1", "kind": "List", "items": objects}))
PYSECRET
unset DB_ADMIN_PASSWORD DB_APP_PASSWORD
unset DB_HOST DB_NAME DB_ADMIN_USER DB_APP_USER

helm upgrade --install "$RELEASE" "$REPO_ROOT/helm/xdevops-training" \
  --namespace "$NS" \
  -f "$REPO_ROOT/helm/xdevops-training/values-$ENVIRONMENT.yaml" \
  --set global.imageRegistry="$ACR" \
  --set global.imageTag="$TAG" \
  --set networkPolicy.postgresSubnetCidr="$(tf output -raw postgres_subnet_cidr 2>/dev/null || echo 10.42.4.0/24)" \
  --wait --timeout 10m

kubectl -n "$NS" get deploy,pod,svc
