# Architecture and evidence boundaries

The simulator intentionally keeps authoritative evidence sources separate.

| Plane | Source of truth | Training question |
|---|---|---|
| Kubernetes | AKS API | What is running now? |
| Metrics | Prometheus | When did behavior change? |
| Logs | Loki | How is the application failing? |
| Azure | ARM via XDevOps Azure adapter | What is the cloud resource state now? |
| KG | XDevOps materialized provider history | What cloud-side configuration/history/provenance is known? |
| Git | This repository | What is the versioned desired state? |
| RAG | `runbooks/` | What is the approved operating procedure? |
| Governance | XDevOps policy/RBAC/HITL | Is this exact operation authorized? |

Git, RAG and KG are not substitutes for live Kubernetes/Azure verification.

## Runtime and infrastructure layers

```text
XDevOps
  ├── Kubernetes / Prometheus / Loki ----> AKS workloads
  ├── Azure ------------------------------> ARM current state
  ├── KG ---------------------------------> cloud history/provenance
  └── Git/RAG ----------------------------> intended state/procedure

Azure training RG
  └── VNet
      ├── AKS subnet -> AKS -> stage/prod namespaces -> application APIs
      └── PostgreSQL delegated subnet -> NSG -> PostgreSQL Flexible Server
```

The KG portion of the course is intentionally cloud/provider-side. Do not infer Kubernetes pod/deployment event provenance from this repository; verify the deployed ontology before making that claim.

## Application dependency map

```text
load-generator
  ├── customer-api ----> Azure PostgreSQL
  └── orders-api ------> Azure PostgreSQL
          ├------------> payments-api
          └------------> inventory-api
```

Process readiness is deliberately separate from dependency health. A workload can remain Running/Ready while a downstream dependency is degraded, giving participants a realistic reason to correlate runtime, application and provider evidence.

## Security boundaries

- AKS administration uses Microsoft Entra/Azure RBAC; local accounts are disabled.
- The configured AKS administrator group is for trainer/platform administration, not participant operator authority.
- XDevOps operator/approver/admin roles remain a separate governance layer.
- Kubernetes NetworkPolicy applies explicit permitted flows; all other ingress/egress is denied by default.
- Application workloads use a non-admin database role.
- The temporary database bootstrap administrator Secret is deleted after deployment.
- Stage/prod namespace separation is real at Kubernetes level; the shared managed PostgreSQL dependency is deliberate for a compact training topology.
