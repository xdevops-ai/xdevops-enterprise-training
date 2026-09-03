# Runbook: customer-api database pool saturation

## Symptoms
- HTTP 5xx rises on customer-api under concurrent load.
- `training_db_connection_failures_total` or pool-acquire timeouts rise.
- PostgreSQL itself remains reachable.

## Evidence required
1. Confirm 5xx/latency in Prometheus.
2. Confirm database/pool timeout events in Loki.
3. Inspect live customer-api environment/configuration in Kubernetes.
4. Compare `DB_POOL_SIZE` and `DB_POOL_ACQUIRE_TIMEOUT_SECONDS` against the approved production values in Git.

## Approved production baseline
- `DB_POOL_SIZE >= 8`; training default is `10`.
- `DB_POOL_ACQUIRE_TIMEOUT_SECONDS >= 1.0`; training default is `2.0`.

## Recovery
Restore the approved Helm values, perform a governed rollout, and verify both application metrics and database failure metrics return to baseline.

## Verification
A successful deployment is not sufficient evidence. Confirm live Kubernetes state, then verify 5xx, p95 latency and DB failure counters.
