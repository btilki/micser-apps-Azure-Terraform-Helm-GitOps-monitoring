# Security

Security model and controls for **Online Boutique on Azure**. Deployment steps: [DEPLOYMENT.md](DEPLOYMENT.md). Architecture: [ARCHITECTURE.md](ARCHITECTURE.md).

---

## Principles

- **No secrets in Git** — tokens in Azure DevOps variable groups; application secrets use Key Vault + CSI (v1 pattern for frontend; see [docs/secrets/key-vault-csi-v1.md](docs/secrets/key-vault-csi-v1.md)).
- **Immutable images in upper environments** — prod/stage use digests promoted from lower ACRs, not ad-hoc rebuilds.
- **Least-privilege network** — default-deny NetworkPolicies with explicit allows.
- **Prod changes are gated** — CODEOWNERS, branch protection, manual Argo CD sync.

---

## Identity, RBAC, and secrets

This section explains **who and what** can access Azure and the cluster, **which roles** apply, and **where secrets live**. Promotion role matrix: [DEPLOYMENT.md — Promotion SP roles](DEPLOYMENT.md#promotion-service-principal-roles). Bootstrap steps: [Phase 2](docs/implementation/phase-02-cluster-bootstrap.md) (Workload Identity for platform), [Phase 3 §2c](docs/implementation/phase-03-first-service-frontend.md#2c-variable-group-and-github_token-github-pr-step) (`GITHUB_TOKEN`).

### How the pieces fit together

```text
Humans ──► GitHub (PR review, CODEOWNERS) ──► GitOps repo
                │
Azure DevOps ───┘  (CI / promote pipelines)
    │
    ├── ARM SP: promotion-azure-connection  ──► ACR push/pull, az acr import
    └── GITHUB_TOKEN (Library secret)       ──► open GitOps digest PRs

AKS kubelet identity ────────────────────────► AcrPull on dev/stage/prod ACRs

Platform pods (cert-manager, external-dns) ──► UAMI via Workload Identity
                                               ──► Azure DNS (records + DNS-01)

App pods (future) ───────────────────────────► per-env UAMI + Key Vault (CSI)

Operators ──► kubectl / Argo CD ─────────────► namespace RBAC + AppProjects
```

There are **three separate RBAC layers**. Do not confuse them:

| Layer | What it controls | Where configured |
|-------|------------------|------------------|
| **Azure RBAC** | ACR, Key Vault, DNS, resource groups | Terraform role assignments; Portal; `az role assignment` |
| **Kubernetes RBAC** | `kubectl` access to namespaces and resources | AAD group bindings (optional); built-in cluster roles |
| **Git + Argo CD** | Who can change prod manifests and who can **Sync** prod | GitHub `CODEOWNERS`, branch protection; Argo `AppProject` + manual sync |

---

### 1. Human and Git access

**GitHub (source of truth for GitOps)**

- All image digests and Helm values change through **pull requests** to `main`.
- **Branch protection** on `main`: required reviews, no direct push.
- **`CODEOWNERS`**: prod paths (`gitops/envs/prod/**`, `gitops/apps/prod/**`) require named approver teams.
- Details: [docs/gitops/prod-branch-protection.md](docs/gitops/prod-branch-protection.md).

**Azure AD (optional, cluster login)**

- Design target: groups such as `g-boutique-devs`, `g-boutique-leads`, `g-boutique-sre` mapped to namespace-scoped Kubernetes roles (edit on `dev`, read-only on `prod` for devs, edit on `prod` for SRE).
- AKS is deployed with **Azure AD integration** and **Workload Identity** enabled (`infra/terraform/modules/aks`).

---

### 2. CI/CD identities (Azure DevOps)

Pipelines do not use personal passwords for Azure or Git. They use a **service connection** and a **Library secret**.

#### `promotion-azure-connection` (Azure Resource Manager)

This is an **Azure AD application (service principal)** used by `AzureCLI@2` tasks in CI and promote pipelines.

| Pipeline / task | Typical Azure roles needed |
|-----------------|---------------------------|
| **CI** (`pipelines/ci/*.yml`) — build and push to dev | **AcrPush** (and **AcrPull**) on `acrboutiquedevweu` |
| **Promote to stage** | **AcrPull** on dev ACR; **AcrPull** + **AcrPush** on stage ACR; **Reader** on `rg-boutique-stage-weu` and `rg-boutique-prod-weu` |
| **Promote to prod** | **AcrPull** on stage ACR; **AcrPush** on prod ACR; **Reader** on the same two RGs |

The promote template runs a **fail-fast RBAC check** before `az acr import`. If a role is missing, the pipeline stops.

**Grant roles in Terraform (optional):** set `promotion_service_principal_object_id` in `infra/terraform/envs/{dev,stage,prod}/terraform.tfvars` and apply — see each env’s `main.tf` for assignments.

**Find the SP object ID:** Azure DevOps → Project settings → Service connections → `promotion-azure-connection` → **Manage Service Principal**.

#### `GITHUB_TOKEN` (Library variable group)

| Setting | Value |
|---------|--------|
| Variable group name | `variable-group-for-microservices` (must match YAML) |
| Secret name | `GITHUB_TOKEN` |
| Purpose | Push a branch and **open a PR** updating `gitops/envs/*/values-*.yaml` after CI or promote |
| Scope | GitHub `repo` (classic) or fine-grained **Contents** + **Pull requests** write on this repository |

Restrict the variable group so only CI and promote pipelines can read it.

---

### 3. Image pull identity (AKS kubelet)

Container images are pulled by the **node kubelet identity**, not by individual pods (unless you add `imagePullSecrets`).

| Identity | Role | Scope |
|----------|------|--------|
| AKS **kubelet** managed identity | **AcrPull** | Each env ACR: `acrboutiquedevweu`, `acrboutiquestageweu`, `acrboutiqueprodweu` |

Terraform grants kubelet **AcrPull** when each env ACR module is applied (`kubelet_object_id` from the shared stack).

**After deploy, attach registries to the cluster** (if pulls fail with `ImagePullBackOff`):

```bash
az aks update -g rg-boutique-shared-weu -n aks-boutique-weu --attach-acr acrboutiquedevweu
az aks update -g rg-boutique-shared-weu -n aks-boutique-weu --attach-acr acrboutiquestageweu
az aks update -g rg-boutique-shared-weu -n aks-boutique-weu --attach-acr acrboutiqueprodweu
```

**Environment isolation** does not rely on kubelet-only pull RBAC per namespace. Each env’s GitOps values file sets `image.repository` to **that env’s ACR login server**; combined with promotion-by-digest, prod pods should only reference prod ACR.

---

### 4. Platform Workload Identity (cert-manager, external-dns)

These controllers run as Kubernetes **ServiceAccounts** and authenticate to Azure using **Workload Identity** (OIDC federation — no client secrets in the cluster).

| Workload | Azure identity (convention) | Azure role | Purpose |
|----------|----------------------------|------------|---------|
| **external-dns** | User-assigned MI (e.g. `id-boutique-external-dns-weu`) | **DNS Zone Contributor** on the DNS zone; **Reader** on DNS RG | Create/update **A records** for Ingress hostnames |
| **cert-manager** | User-assigned MI (client ID in Helm values) | **DNS Zone Contributor** (DNS-01 solver) | Complete **Let’s Encrypt** challenges via Azure DNS TXT records |

Configuration files (replace `YOUR_*` before Phase 2):

- `gitops/apps/platform/external-dns/azure.json`, `values.yaml`
- `gitops/apps/platform/cert-manager/clusterissuer.yaml`, `values.yaml`

**Federated credential** ties each UAMI to a fixed Kubernetes subject, for example:

```text
system:serviceaccount:external-dns:external-dns
```

Setup commands: [Phase 2 — external-dns and cert-manager](docs/implementation/phase-02-cluster-bootstrap.md).

Helm values annotate ServiceAccounts with `azure.workload.identity/client-id: "<UAMI client ID>"`.

---

### 5. Application secrets (Key Vault + CSI) — v1 (frontend)

Each environment has its own Key Vault (Terraform `infra/terraform/envs/{dev,stage,prod}`):

| Environment | Vault name (convention) |
|-------------|-------------------------|
| dev | `kv-boutique-dev-weu` |
| stage | `kv-boutique-stage-weu` |
| prod | `kv-boutique-prod-weu` |

**v1:** AKS **Key Vault Secrets Provider** add-on; per-env UAMI for **frontend** (`modules/workload_identity`); dev `SecretProviderClass` in `gitops/platform/dev/`; optional Helm mount in `charts/frontend` (off by default). Guide: [docs/secrets/key-vault-csi-v1.md](docs/secrets/key-vault-csi-v1.md).

**Not yet:** CSI for other microservices; full demo secret migration.

**Design reference:** [docs/architecture-design.md §9](docs/architecture-design.md#9-identity-rbac-secrets).

---

### 6. Kubernetes and Argo CD access control

| Mechanism | Purpose |
|-----------|---------|
| **Namespaces** `dev`, `stage`, `prod` | Logical isolation on one cluster |
| **NetworkPolicy** + **Pod Security** labels | Restrict traffic and pod capabilities — [policies/README.md](policies/README.md) |
| **Argo CD AppProject** `boutique-stage`, `boutique-prod` | Limit which repo paths and destination namespaces child Applications may use |
| **Manual prod sync** | Prod `Application` manifests have **no** `syncPolicy.automated`; an operator must **Sync** after a prod GitOps PR merges |
| **Argo CD repo credential** | Kubernetes `Secret` or UI repo entry so Argo can clone GitHub (PAT or token — not committed to Git) |

Restrict who can click **Sync** on prod apps via Argo CD RBAC / SSO groups in your organization.

---

### 7. What must never be in Git

| Secret type | Store instead |
|-------------|----------------|
| GitHub PAT for pipelines | Azure DevOps Library — `GITHUB_TOKEN` |
| Azure SP client secrets (if used) | Service connection / Key Vault; prefer **Workload Identity Federation** for ADO |
| TLS private keys, DB passwords, API keys | Key Vault → CSI mount |
| `YOUR_TENANT_ID`, managed identity client IDs | Replace in platform YAML locally or via secure pipeline; do not commit real tenant-specific values in public forks |

Find leftover placeholders: [DEPLOYMENT.md — Fork setup](DEPLOYMENT.md#fork-setup-replace-placeholders).

---

## Runtime hardening

Guardrails live in `gitops/platform/<env>/` (NetworkPolicy, PSS labels, quotas). Summary: [ARCHITECTURE.md — Cluster layout](ARCHITECTURE.md#cluster-layout). Paths and validation: [policies/README.md](policies/README.md), [Phase 8](docs/implementation/phase-08-hardening.md).

---

## Supply chain

- **Trivy** in every `pipelines/ci/*.yml` — fail build on **HIGH** and **CRITICAL** vulnerabilities.
- **Digest pinning** in `gitops/envs/*/values-*.yaml` — deploy by `sha256:...`, not floating tags, for owned services.
- **Promotion** — `az acr import` copies manifest by digest; RBAC validated before import (see [Identity, RBAC, and secrets](#identity-rbac-and-secrets)).

---

## Observability and alerting

- Alertmanager routes in `gitops/apps/platform/kube-prometheus-stack/values.yaml` — replace `REPLACE_*` webhook/email placeholders before relying on pages.
- Routes cover crash loops, ingress 5xx, certificate expiry. Detail: [docs/observability/ingress-5xx-and-cert-alerts.md](docs/observability/ingress-5xx-and-cert-alerts.md).

Configure in [Phase 7](docs/implementation/phase-07-prod-environment.md).

---

## Reporting vulnerabilities

If you discover a security issue in this repository, report it privately to the repository owner rather than opening a public issue with exploit details.

