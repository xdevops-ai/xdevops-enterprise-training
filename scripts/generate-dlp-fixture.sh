#!/usr/bin/env bash
set -euo pipefail

OUT="${1:-/tmp/xdevops-training-dlp-fixture.txt}"
# Deliberately assemble synthetic values at runtime so no credential-shaped
# token is stored in Git history. These values are fake and unusable.
FAKE_ACCESS_KEY="$(printf '%s%s' 'AKIA' '0000000000000000')"
FAKE_TOKEN="$(printf '%s%s' 'sk-training-' '000000000000000000000000')"
cat > "$OUT" <<FIXTURE
XDEVOPS_TRAINING_DLP_FIXTURE=TRUE
AWS_ACCESS_KEY_ID=$FAKE_ACCESS_KEY
DATABASE_PASSWORD=TRAINING_FAKE_PASSWORD_DO_NOT_USE
API_TOKEN=$FAKE_TOKEN
FIXTURE
chmod 600 "$OUT"
echo "Created ephemeral synthetic DLP fixture: $OUT"
echo "Do not commit this generated file."
