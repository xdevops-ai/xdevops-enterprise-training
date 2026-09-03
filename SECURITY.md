# Security policy

## Supported scope

This repository contains a short-lived enterprise training simulator. It is not a production reference architecture and must not be used to store real customer data, production credentials, or production Terraform state.

## Reporting a vulnerability

Do **not** open a public issue containing a suspected secret, exploitable configuration, tenant identifier, or security-sensitive reproduction detail.

Use the repository host's private security-advisory mechanism when available, or the organization's published security contact/channel. Include only the minimum information required to reproduce the issue.

## Repository rules

- Never commit Azure credentials, service-principal secrets, client secrets, access tokens, kubeconfigs, certificates/private keys, `.env` files, or Terraform state.
- Keep customer names, tenant IDs, subscription IDs, endpoint IDs, participant identities, and workshop access details out of the public repository.
- Use only dedicated training subscriptions/resource groups and synthetic data.
- Generate DLP/redaction fixtures at runtime with `scripts/generate-dlp-fixture.sh`; never substitute real credentials.
- Require review for changes to Terraform, IAM/RBAC, network policy, GitHub Actions, Dockerfiles, or deployment scripts.
- Run `./scripts/public-release-check.sh` before each public push.

## Deployment responsibility

The Terraform and Kubernetes manifests are intentionally opinionated for a bounded training lab. Organizations remain responsible for validating them against their own cloud policies, compliance requirements, private networking model, identity architecture, cost controls, and supported software versions.
