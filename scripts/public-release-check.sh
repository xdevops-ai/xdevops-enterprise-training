#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

fail=0
say_fail() { echo "ERROR: $*" >&2; fail=1; }

# Keep customer-specific tokens split in source so this checker does not flag itself.
CUSTOMER_TOKEN="k""yos"
CUSTOMER_DOMAIN="${CUSTOMER_TOKEN}.ch"

if grep -RIni --exclude-dir=.git --exclude='public-release-check.sh' -E "${CUSTOMER_TOKEN}|${CUSTOMER_DOMAIN}" . >/tmp/xdevops-public-customer-hits 2>/dev/null; then
  cat /tmp/xdevops-public-customer-hits >&2
  say_fail "customer-specific reference found"
fi

# Common credential/private-key signatures. This is intentionally conservative and
# complements, rather than replaces, the repository host's secret scanning.
if grep -RIni --exclude-dir=.git --exclude='public-release-check.sh' \
  -E 'AKIA[0-9A-Z]{16}|-----BEGIN ([A-Z0-9 ]+ )?PRIVATE KEY-----|AccountKey=[A-Za-z0-9+/=]{20,}|client_secret[[:space:]]*=[[:space:]]*[^<[:space:]]+' . \
  >/tmp/xdevops-public-secret-hits 2>/dev/null; then
  cat /tmp/xdevops-public-secret-hits >&2
  say_fail "credential-shaped content found"
fi

# Files that must never be tracked in the public repository.
tracked="$(git ls-files)"
while IFS= read -r path; do
  [[ -z "$path" ]] && continue
  case "$path" in
    *.tfstate|*.tfstate.*|*.tfplan|terraform.tfvars|*/terraform.tfvars|*.pem|*.key|*.pfx|*.p12|*.kubeconfig|kubeconfig|*/kubeconfig|.env|*/.env|backend.tf|*/backend.tf)
      say_fail "sensitive/generated file is tracked: $path" ;;
  esac
done <<< "$tracked"

# Public participant repo must not contain private trainer material.
if find . -path './.git' -prune -o -type d -name scenarios -print -quit | grep -q .; then
  say_fail "trainer-only scenarios directory is present"
fi
if find . -type f \( -name 'ACCEPTANCE_TEST.md' -o -name 'TRAINING_VALUE_MAP.md' -o -name 'ENTERPRISE_READINESS.md' -o -name 'XDEVOPS_INTEGRATION.md' \) -print -quit | grep -q .; then
  say_fail "trainer-only/maintainer answer material is present"
fi

# Full-history checks matter before public release. The repo is deliberately small.
if git rev-parse --git-dir >/dev/null 2>&1; then
  if git log --all --format='%B' | grep -i -E "${CUSTOMER_TOKEN}|${CUSTOMER_DOMAIN}" >/tmp/xdevops-history-customer-hits 2>/dev/null; then
    cat /tmp/xdevops-history-customer-hits >&2
    say_fail "customer-specific reference exists in Git commit messages"
  fi
  for commit in $(git rev-list --all); do
    if git grep -I -n -E "${CUSTOMER_TOKEN}|${CUSTOMER_DOMAIN}" "$commit" -- . \
       ':!scripts/public-release-check.sh' >/tmp/xdevops-history-customer-hits 2>/dev/null; then
      cat /tmp/xdevops-history-customer-hits >&2
      say_fail "customer-specific reference exists in Git history"
      break
    fi
    if git grep -I -n -E 'AKIA[0-9A-Z]{16}|-----BEGIN ([A-Z0-9 ]+ )?PRIVATE KEY-----|AccountKey=[A-Za-z0-9+/=]{20,}' "$commit" -- . \
       ':!scripts/public-release-check.sh' >/tmp/xdevops-history-secret-hits 2>/dev/null; then
      cat /tmp/xdevops-history-secret-hits >&2
      say_fail "credential-shaped content exists in Git history"
      break
    fi
  done
fi

rm -f /tmp/xdevops-public-customer-hits /tmp/xdevops-public-secret-hits /tmp/xdevops-history-customer-hits /tmp/xdevops-history-secret-hits

if [[ "$fail" != "0" ]]; then
  exit 1
fi

echo "Public release checks passed."
echo "Note: also enable the repository host's secret scanning and organization-approved SAST/IaC/container scanning."
