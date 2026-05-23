# Security

Security model and controls for **Online Boutique on Azure**. Deployment steps: [DEPLOYMENT.md](DEPLOYMENT.md). Architecture: [ARCHITECTURE.md](ARCHITECTURE.md).

---

## Principles

- **No secrets in Git** — tokens in Azure DevOps variable groups; app secrets in Key Vault via CSI driver.
- **Immutable images in upper environments** — prod/stage use digests promoted from lower ACRs, not ad-hoc rebuilds.
- **Least-privilege network** — default-deny NetworkPolicies with explicit allows.
- **Prod changes are gated** — CODEOWNERS, branch protection, manual Argo CD sync.

---

## Identity and access

### Azure DevOps / CI

| Asset | Control |
|-------|---------|
| `promotion-azure-connection` | ARM service principal; **AcrPush** on dev ACR for CI; promotion roles per [DEPLOYMENT.md](DEPLOYMENT.md#promotion-service-principal-roles) |
| `GITHUB_TOKEN` | Secret in `variable-group-for-microservices`; `repo` scope (or fine-grained PR + contents) for GitOps PRs only |
| Pipeline permissions | Limit variable group access to required pipelines |

Resolve SP object ID: Azure DevOps → Service connections → **Manage Service Principal**.

### Kubernetes / Azure

- **Workload Identity** for cert-manager and external-dns (managed identities; federated credentials on AKS OIDC issuer).
- **Per-environment ACR** — kubelet pulls from env registry; `az aks update --attach-acr` per registry.
- **Argo CD** — repository credentials via K8s secret or UI; restrict who can sync **prod** (`boutique-prod` AppProject).

### Production GitOps

- **CODEOWNERS** on `gitops/envs/prod/**` and `gitops/apps/prod/**`.
- Branch protection on `main`: required reviews, no direct push.
- Details: [docs/gitops/prod-branch-protection.md](docs/gitops/prod-branch-protection.md).

---

## Runtime hardening

Shipped under `gitops/platform/<env>/` (synced by `platform-dev`, `platform-stage`, `platform-prod`):

| Control | dev | stage / prod |
|---------|-----|----------------|
| Pod Security labels | `baseline` | `restricted` |
| NetworkPolicy | default-deny + baseline ingress/egress | tighter egress in prod |
| ResourceQuota / LimitRange | yes | yes (stricter in prod) |

Helm charts set `securityContext` (non-root, dropped caps) in `charts/*/values.yaml` and templates.

Index: [policies/README.md](policies/README.md). Validation: [Phase 8](docs/implementation/phase-08-hardening.md).

---

## Supply chain

- **Trivy** in every `pipelines/ci/*.yml` — fail build on **HIGH** and **CRITICAL** vulnerabilities.
- **Digest pinning** in `gitops/envs/*/values-*.yaml` — deploy by `sha256:...`, not floating tags, for owned services.
- **Promotion** — `az acr import` copies manifest by digest; RBAC validated before import.

---

## Secrets management

- **Key Vault** per environment (Terraform `infra/terraform/envs/{dev,stage,prod}`).
- **CSI Secrets Store driver** — mount secrets into pods; do not commit secret values.
- Replace `YOUR_*` in platform Helm values before cluster bootstrap ([DEPLOYMENT.md — Fork setup](DEPLOYMENT.md#fork-setup-replace-placeholders)).

---

## Observability and alerting

- Alertmanager routes in `gitops/apps/platform/kube-prometheus-stack/values.yaml` — replace `REPLACE_*` webhook/email placeholders before relying on pages.
- Routes cover crash loops, ingress 5xx, certificate expiry.

Configure in [Phase 7](docs/implementation/phase-07-prod-environment.md).

---

## Reporting vulnerabilities

If you discover a security issue in this repository, report it privately to the repository owner rather than opening a public issue with exploit details.

---

## Related

- [TROUBLESHOOTING.md](TROUBLESHOOTING.md) — cert/TLS and ingress incidents
- [docs/runbooks/](docs/runbooks/README.md) — operational response
