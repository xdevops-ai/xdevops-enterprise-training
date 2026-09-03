# Runbook: AKS to Azure PostgreSQL connectivity

## Expected topology
AKS nodes originate from the AKS subnet and connect to PostgreSQL TCP/5432 through `nsg-postgres-training` on the delegated PostgreSQL subnet.

## Normal rule
`postgres-from-aks`: inbound TCP/5432 from the AKS subnet CIDR, access `Allow`.

## Symptoms of an NSG deny
- customer-api and orders-api processes remain Running/Ready.
- DB operations time out and HTTP 5xx rises.
- Kubernetes may show no pod restart or configuration change.

## Evidence required
1. Prometheus: DB failures/latency and HTTP 5xx.
2. Loki: `database_connection_timeout` / DB operation failures.
3. Kubernetes: prove the pods are still Running and application config did not change.
4. Azure: read the current NSG rule.
5. KG: inspect configuration history/provenance for the NSG/rule after materialization.

## Recovery
Only restore the exact `postgres-from-aks` rule from `Deny` to `Allow`. Do not delete the NSG and do not change unrelated rules.

## Verification
- Azure current state = Allow.
- KG records the new provider-side state/history.
- DB timeout logs stop.
- HTTP 5xx and latency recover.
