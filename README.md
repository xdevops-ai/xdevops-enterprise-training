# XDevOps Enterprise Training Environment

A public-safe, production-like simulator for demonstrating evidence-driven and governed infrastructure operations with XDevOps.ai.

The repository creates **one application runtime on AKS** and surrounds it with Azure infrastructure that can be investigated through separate evidence planes:

- Kubernetes: `!k8s`
- Prometheus: `!metric`
- Loki: `!loki` / `!logs`
- Azure: `!azure`
- Knowledge Graph: `!kg` / `!ontology`
- Git / curated knowledge: repository search / `!knowledge`
- IaC lifecycle: `!template`

The simulator does not fake chatbot answers. The workloads generate real Kubernetes state, metrics, structured logs, Git history, and Azure resource state so a training session can demonstrate how evidence, authorization, execution, and verification differ.

> **Scope:** this is an enterprise training simulator, not a production reference architecture. Review your organization's security, networking, identity, cost, compliance, and data-retention requirements before deployment.

## Architecture

```text
Azure training resource group
└── VNet 10.42.0.0/16
    ├── AKS subnet 10.42.0.0/22
    │   └── AKS (Azure CNI Overlay + Cilium)
    │       ├── xdevops-training-stage
    │       └── xdevops-training-prod
    │           ├── customer-api
    │           ├── orders-api
    │           ├── payments-api
    │           ├── inventory-api
    │           └── load-generator
    └── PostgreSQL subnet 10.42.4.0/24
        ├── NSG: nsg-postgres-training
        │   └── postgres-from-aks : TCP/5432 Allow (baseline)
        └── Azure PostgreSQL Flexible Server (private only)
```

Stage and prod are separate Kubernetes namespaces on the same short-lived training cluster. The managed PostgreSQL service is a deliberate shared dependency so engineers can investigate cross-layer effects without duplicating the application.

## Enterprise baseline

The default design includes:

- Microsoft Entra/Azure RBAC on AKS with local accounts disabled.
- OIDC and Workload Identity enabled.
- Azure CNI Overlay with Cilium network policy/data plane.
- a private-only PostgreSQL Flexible Server in a delegated subnet with private DNS.
- a least-privilege PostgreSQL application role; application workloads do not use the server administrator account.
- a temporary DB bootstrap administrator Secret that is removed after schema bootstrap.
- non-root application containers, read-only root filesystems, dropped capabilities, no privilege escalation, and `RuntimeDefault` seccomp.
- no application service-account token mounts.
- namespace quotas/limits, Pod Security `restricted`, default-deny NetworkPolicies, and PDBs.
- Git-derived release tags, recorded image digests, and locked ACR tags.
- an explicit Terraform guard that prevents a public AKS API without authorized CIDRs unless a rehearsal-only override is deliberately set.

For a longer-lived or production-like deployment, add the organization's approved secret manager, private AKS API connectivity, HA/resilience patterns, policy-as-code, image signing/SBOM, and environment isolation controls.

## Public repository safety

This repository is intentionally safe to publish:

- no customer-specific names or tenant identifiers are required;
- no Azure subscription, tenant, endpoint, or Kubernetes credentials are committed;
- Terraform state, `terraform.tfvars`, `.env`, kubeconfigs, keys, generated image metadata, and local backend files are ignored;
- the committed DLP fixture contains no credential-shaped value;
- `scripts/generate-dlp-fixture.sh` creates synthetic test data outside the repository at runtime;
- trainer-only answer keys, reset controls, customer configuration, endpoint IDs, and workshop accounts must remain in a separate private repository/package.

Run this before every public push:

```bash
./scripts/public-release-check.sh
```

See `docs/PUBLIC_RELEASE.md` and `SECURITY.md` before publishing.

## Prerequisites

- Dedicated Azure training subscription or an explicitly isolated training resource group.
- Azure CLI authenticated with provisioning permissions.
- Terraform >= 1.13 and < 2.0.
- `kubectl` compatible with the deployed AKS version.
- `kubelogin` for Microsoft Entra-backed AKS authentication.
- Helm 4.x for the course baseline, or another organization-approved supported version.
- Microsoft Entra group object ID for trainer/platform administration.
- Prometheus and Loki integrations, or approved equivalents, accessible to XDevOps.
- Git remote accessible to the XDevOps repository-ingestion path.
- Encrypted, access-controlled remote Terraform state for shared/course use.

## 1. Configure Terraform

```bash
cd infrastructure/terraform/environments/training
cp terraform.tfvars.example terraform.tfvars
```

Replace every placeholder. At minimum set:

- `subscription_id`
- `expires_on`
- `aks_admin_group_object_ids`
- either `aks_private_cluster_enabled = true` **or** approved `aks_api_server_authorized_ip_ranges`
- naming/location values when required

The public example intentionally does not include a usable subscription, group ID, or AKS API allowlist.

### Remote state

`backend.tf.example` contains the backend block. Copy it to `backend.tf` and initialize with your approved Azure Storage backend:

```bash
cp backend.tf.example backend.tf
terraform init \
  -backend-config="resource_group_name=<state-rg>" \
  -backend-config="storage_account_name=<state-account>" \
  -backend-config="container_name=tfstate" \
  -backend-config="key=xdevops-enterprise-training.tfstate" \
  -backend-config="use_azuread_auth=true"
```

Do not use local Terraform state for a shared workshop because generated database credentials are present in state.

## 2. Static validation

From the repository root:

```bash
./scripts/public-release-check.sh
./scripts/validate.sh
```

Static validation checks Python/shell syntax, Terraform formatting/validation, Helm lint/rendering, public-release hygiene, and participant-repository boundaries. It does not replace an Azure plan or live acceptance test.

## 3. Provision Azure

```bash
cd infrastructure/terraform/environments/training
terraform plan -out training.tfplan
terraform apply training.tfplan
```

## 4. Build immutable course images

For the enterprise course baseline, provide organization-approved digest-pinned base images:

```bash
PYTHON_BASE_IMAGE='python:3.12-slim@sha256:<approved-digest>' \
POSTGRES_BASE_IMAGE='postgres:16-alpine@sha256:<approved-digest>' \
ENFORCE_PINNED_BASE_IMAGES=1 \
./scripts/build-images.sh
```

For rehearsal only, mutable base tags are allowed with an explicit warning. The release tag defaults to the `main` Git commit; image digests are recorded locally and ACR tags are locked after build.

## 5. Deploy stage and prod

```bash
./scripts/deploy.sh stage
./scripts/deploy.sh prod
```

The deploy script obtains Entra-backed AKS credentials, applies namespace security labels, creates a least-privilege application DB Secret, creates a temporary PostgreSQL administrator Secret for schema bootstrap, reconciles the Helm release, deletes the administrator Secret, and waits for workloads to become ready.

If Prometheus runs in another namespace, label that namespace so the explicit NetworkPolicy permits metrics scraping:

```bash
kubectl label namespace <monitoring-namespace> training.xdevops.ai/metrics-access=true --overwrite
```

## 6. Preflight

```bash
./scripts/preflight.sh
```

The preflight validates machine-checkable cloud and workload guardrails. Workshop-specific XDevOps governance, KG, evidence, role-separation, and negative-control acceptance tests belong in the private trainer package.

## 7. Configure XDevOps evidence sources

Create/load endpoints for:

- the Azure subscription or training-resource-group scope;
- the AKS cluster;
- Prometheus;
- Loki.

Ingest this repository as the Git source and `runbooks/` as curated knowledge in the intended tenant/ACL scope. Push all intended training refs if repository-history exercises depend on them.

Before a course, validate the exact ontology/KG questions against the deployed XDevOps tenant. Do not assume Kubernetes pod/deployment history exists in KG; this simulator uses KG for provider-side cloud materialization/provenance.

## Repository layout

```text
infrastructure/terraform/       Azure foundation
services/                       FastAPI services + load generator
helm/xdevops-training/          Kubernetes deployment + guardrails
runbooks/                       curated operational knowledge
fixtures/dlp/                   public-safe DLP fixture documentation
scripts/                        build, deploy, validate, preflight, release checks
 docs/                          architecture and public-release guidance
```

## Evidence authority rule

Never teach that one evidence plane is universally authoritative:

- Kubernetes tells you what is running.
- Prometheus tells you when behavior changed.
- Loki tells you how the application failed.
- Azure tells you current cloud-resource state.
- KG tells you cloud history/provenance materialized by XDevOps.
- Git tells you versioned desired state.
- RAG tells you approved procedure.
- Governance decides whether a proposed mutation may execute.
- Independent verification proves whether the objective was achieved.

## License

This public package intentionally does not select an open-source license on behalf of the repository owner. A public repository without an explicit license remains protected by default copyright rules. Add the organization-approved license before inviting external reuse or contributions.
