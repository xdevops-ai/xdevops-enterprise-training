# Contributing

This repository is primarily an enterprise training simulator. Keep contributions deterministic, public-safe, and useful for evidence-driven operations training.

Before opening a pull request:

1. Do not add customer-specific configuration, credentials, tenant/subscription identifiers, workshop accounts, private endpoints, or trainer answer keys.
2. Run `./scripts/public-release-check.sh`.
3. Run `./scripts/validate.sh` with the supported Terraform/Helm toolchain.
4. Keep faults bounded to the dedicated training environment and reversible.
5. Preserve evidence boundaries: Git/RAG/KG are not substitutes for live Kubernetes/Azure verification.
6. Do not weaken the secure defaults solely to make a demo easier.

Security-sensitive findings should follow `SECURITY.md`, not a public issue.

No contribution or reuse license is implied by this file; the repository owner should add an organization-approved license before accepting external contributions.
