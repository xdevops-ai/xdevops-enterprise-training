# Public release checklist

Run this checklist before making the repository public and before each tagged public release.

## Identity and confidentiality

- [ ] No customer/client names or logos.
- [ ] No employee, participant, tenant, subscription, endpoint, or account identifiers.
- [ ] No internal hostnames, private repository URLs, VPN details, or workshop credentials.
- [ ] Trainer-only controls and answer keys remain in a separate private package.

## Secrets and generated data

- [ ] `./scripts/public-release-check.sh` passes on all refs.
- [ ] No `.env`, kubeconfig, certificate/private-key, Terraform state, plan, or `terraform.tfvars` is tracked.
- [ ] No credential-shaped synthetic fixture is committed.
- [ ] DLP fixtures are generated ephemerally outside the repository.

## Infrastructure safety

- [ ] Public AKS API access is either disabled or restricted to approved CIDRs.
- [ ] Local AKS accounts remain disabled.
- [ ] PostgreSQL public network access remains disabled.
- [ ] ACR admin credentials remain disabled.
- [ ] Training resources have an expiry/cost-governance tag.
- [ ] Terraform state is remote, encrypted, and access controlled for shared use.

## Supply chain

- [ ] Terraform provider versions are reviewed.
- [ ] Python dependencies are pinned and scanned by the organization's approved tooling.
- [ ] Course images are built from approved digest-pinned base images for formal delivery.
- [ ] Generated release images are scanned and, where required, signed/SBOM-attested.

## Legal/product review

- [ ] Public documentation describes capabilities accurately and does not expose confidential implementation details.
- [ ] The repository owner has selected an approved license if third-party reuse/contributions are intended.
- [ ] Trademark/branding use is approved.

## Repository-host controls

For GitHub, enable before announcing the repository:

- [ ] Secret scanning and push protection.
- [ ] Dependabot alerts and security updates.
- [ ] Code scanning/CodeQL.
- [ ] Branch protection or rulesets for `main` with pull-request review and required CI checks.
- [ ] Private vulnerability reporting/security advisories if available.
- [ ] Restrict Actions permissions to read-only by default; grant job-specific permissions only where required.
