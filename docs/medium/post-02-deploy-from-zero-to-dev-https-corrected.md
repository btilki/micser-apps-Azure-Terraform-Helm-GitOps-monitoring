# Medium Draft — Part 2 of 3

**Suggested Title:** From Clone to HTTPS: Deploying Online Boutique on Azure (Terraform, AKS, and Your First Pipeline)  
**Subtitle:** Part 2 of 3 — Bootstrap state, install the platform stack, register Azure DevOps CI, and open the dev storefront  
**Tags (pick 5):** Azure, Kubernetes, Terraform, AKS, Helm, Argo CD, DevOps, Tutorial  
**Repo Link (use in story):** https://github.com/btilki/micser-apps-Azure-Terraform-Helm-GitOps-monitoring  

**Images for Medium (from repo `docs/diagrams/`):**  
1. `02-azure-resources.png`, `03-inside-cluster.png`, `01-cicd-flow.png`  
2. `azure-devops-settings-service-connections.png`, `azure-devops-library-variable-group-github-token.png`  

---

*Part 2 of 3. [Part 1](post-01-architecture-and-choices-corrected.md) explained the design. Here we deploy. [Part 3](post-03-promote-prod-and-operations-corrected.md) covers stage/prod promotion and day-two operations.*

---

In [Part 1](https://github.com/btilki/micser-apps-Azure-Terraform-Helm-GitOps-monitoring/blob/main/docs/medium/post-01-architecture-and-choices-corrected.md) I described *why* this platform uses one AKS cluster. Now we build it, step by step.

The repository already contains charts, GitOps manifests, and pipeline YAML—you configure identities and run the phases in order.

**Repository:** https://github.com/btilki/micser-apps-Azure-Terraform-Helm-GitOps-monitoring  

Detailed checklists live in `DEPLOYMENT.md` and `docs/implementation/phase-*.md`. I summarize the spine here so you can publish or follow without opening ten files at once.

---

## Before You Start

Install and verify:

```bash
terraform version
az version
kubectl version --client
helm version
git --version
```

You need an Azure subscription, permission to create resource groups and AKS, a DNS zone you control (for TLS via DNS-01), GitHub (for GitOps PRs from pipelines), and an Azure DevOps project (for CI).

**Fork Setup:** If you fork the repo, replace placeholders for `repoURL` in GitOps, `GITHUB_REPOSITORY` in CI YAML, `githubRepository` in promote YAML, `YOUR_ORG` in CODEOWNERS, and tenant/DNS IDs in cert-manager and external-dns Helm values.

Use `rg` (ripgrep) to find and verify replacements:

```bash
rg 'btilki/micser-apps-Azure-Terraform-Helm-GitOps-monitoring|YOUR_ORG'
rg 'YOUR_TENANT_ID' gitops/apps/platform
```

---

## Phase Map (What You Will Run)

| Order | Focus | Outcome |
|-------|-------|---------|
| 0 | Repo scaffolding | Branch protection, CODEOWNERS |
| 1 | Terraform | State, VNet, AKS, per-env ACR and Key Vault |
| 2 | Cluster bootstrap | Ingress, cert-manager, external-dns, monitoring, Argo CD |
| 3 | First service | Register `pipelines/ci/frontend.yml`, merge digest PR, HTTPS dev URL |

Phases 4–7 (promotion, stage, prod) are in [Part 3](post-03-promote-prod-and-operations-corrected.md).

---

## Terraform: Bootstrap → Shared → Environments

Apply in this order only:

1. **`infra/terraform/envs/bootstrap`** — Remote state storage (once per subscription).
2. **`infra/terraform/envs/shared`** — VNet, Log Analytics, public DNS zone, AKS `aks-boutique-weu`, static ingress IP.
3. **`infra/terraform/envs/dev`** (then stage/prod when ready) — Environment resource group, dedicated ACR, Key Vault.

Copy each stack's `*.tfvars.example` → `terraform.tfvars` and `backend.hcl.example` → `backend.hcl` before `terraform init` and `apply`.

**[Insert image: 02-azure-resources.png — caption: Bootstrap state, shared platform, and per-environment registries.]**

Why three applies? **Blast radius and permissions:** shared infrastructure is long-lived; env stacks can be destroyed or recreated without touching the cluster definition. The dev ACR name in the frontend pipeline must match what Terraform outputs.

After Phase 1, capture outputs:

```bash
cd infra/terraform/envs/dev && terraform output
```

You will need ACR login server, resource group names, and Key Vault URIs in later steps.

---

## Cluster Bootstrap: Platform Before Apps

With `kubectl` pointed at the cluster, follow [Phase 2](https://github.com/btilki/micser-apps-Azure-Terraform-Helm-GitOps-monitoring/blob/main/docs/implementation/phase-02-cluster-bootstrap.md). **Important:** the repo installs platform software with **`helm upgrade --install`** first (ingress, cert-manager, external-dns, monitoring, Argo CD). Only after that do you apply the Argo **root app** so child Applications can sync workloads and policies from Git.

| Component | How it is installed (this repo) |
|-----------|----------------------------------|
| **ingress-nginx** | Helm CLI → `ingress-nginx` namespace (not an Argo `Application`) |
| **cert-manager**, **external-dns**, **kube-prometheus-stack** | Helm CLI using values under `gitops/apps/platform/` |
| **Argo CD** | Helm CLI → `argocd` namespace |
| **Workloads + namespace policies** | Argo root app → `gitops/bootstrap/applications/` |

**[Insert image: 03-inside-cluster.png — caption: Platform namespaces and app namespaces on one cluster. Export optional; see `docs/diagrams/README.md`.]**

Copy `gitops/bootstrap/root-app.yaml.example` to `gitops/bootstrap/root-app.yaml`, set **`repoURL`** and **`targetRevision`** (usually `main`), then:

```bash
kubectl apply -n argocd -f gitops/bootstrap/root-app.yaml
```

After sync you should see Argo Applications such as `apps-dev`, `platform-dev`, and `platform-monitoring`—not a separate Argo app for ingress-nginx (check ingress with `kubectl get pods -n ingress-nginx`).

Sanity checks:

```bash
kubectl get nodes
kubectl get applications -n argocd
kubectl get pods -n ingress-nginx,cert-manager,external-dns,argocd
```

Do not skip Helm platform install—frontend TLS depends on cert-manager and external-dns being healthy.

---

## Azure DevOps: Connections the Pipelines Expect

Register once per project:

| Name | Purpose |
|------|---------|
| `promotion-azure-connection` | ARM service connection for `AzureCLI@2` (build, push, `az acr import`) |
| `variable-group-for-microservices` | Library group holding secrets |
| `GITHUB_TOKEN` | Secret in the group — opens GitOps digest PRs on GitHub |

**[Optional: Insert azure-devops-settings-service-connections.png and azure-devops-library-variable-group-github-token.png.]**

The promotion service principal needs **AcrPush** on dev ACR for CI; promote pipelines add **AcrPull**/**AcrPush** on stage/prod registries (see `DEPLOYMENT.md` — Promotion SP roles). The shared template ensures consistent secret resolution across all pipelines.

---

## First CI Run: Frontend to Dev

The repo already ships:

| Artifact | Path |
|----------|------|
| Helm chart | `charts/frontend/` |
| Dev Application | `gitops/apps/dev/` (via umbrella `apps-dev`) |
| Dev values (digest updated by CI) | `gitops/envs/dev/values-frontend.yaml` |
| CI pipeline | `pipelines/ci/frontend.yml` |
| Dockerfile | `apps/frontend/Dockerfile` |

**Register the Pipeline:** In Azure DevOps → **Pipelines** → **New pipeline** → GitHub → your fork → **Existing Azure Pipelines YAML file** → path `/pipelines/ci/frontend.yml`. The YAML sets **`trigger: none`** — run the pipeline manually until you re-enable push/PR triggers.

**What One Run Does:**

1. Builds and pushes an image to **dev ACR**.
2. Scans with **Trivy** (fails on high/critical vulnerabilities).
3. Opens a GitHub PR updating `image.digest` in `gitops/envs/dev/values-frontend.yaml`.

**[Insert image: 01-cicd-flow.png — caption: CI builds to dev ACR; merge the GitOps PR; Argo CD deploys to the dev namespace.]**

Set `ingress.host` in dev values to your hostname (e.g., `dev.boutique.example.com`). Keep `googleDemo.enabled: false` when using your own image—otherwise the chart can route to upstream ExternalName services and skip your build.

After merge:

- Argo CD syncs the dev frontend Application (auto-sync on dev is typical).
- Wait for cert-manager to issue the certificate and external-dns to create the record.
- Verify:

```bash
kubectl get pods -n dev
curl -sS -o /dev/null -w "%{http_code}\n" https://dev.boutique.example.com/
```

Expect **200** when the rollout and TLS are complete.

---

## Fan-Out (Same Pattern, More Services)

v1 builds five owned workloads: **frontend**, **cartservice**, **currencyservice**, **productcatalogservice**, **redis-cart**. Each has `pipelines/ci/<service>.yml`, a chart under `charts/`, and values in `gitops/envs/dev/values-<service>.yaml`.

Upstream Google images (checkout, payment, email, etc.) can be enabled later for the full demo journey without this repo rebuilding them.

---

## When Something Fails

| Symptom | First Look |
|---------|------------|
| Pipeline cannot push to ACR | SP roles on dev ACR; service connection subscription |
| No GitOps PR | `GITHUB_TOKEN` in variable group; `GITHUB_REPOSITORY` in YAML |
| Certificate pending | DNS zone IDs in cert-manager/external-dns; Workload Identity |
| 503 on storefront | `googleDemo.enabled`, pod logs, Ingress backend |
| Argo OutOfSync | Diff in values; manual sync on dev if needed |

Full index: `TROUBLESHOOTING.md` and `docs/runbooks/`.

---

## What You Should Have Now

- Terraform-managed Azure foundation and **dev** ACR with at least one image.
- Platform controllers and Argo CD reconciling from Git.
- A merged digest PR and a **HTTPS** dev storefront URL.
- Confidence that the next move is **promotion**, not rebuilding for stage.

---

## Next

[Part 3](post-03-promote-prod-and-operations-corrected.md): `az acr import` to stage and prod, manual prod Argo sync, alerts, rollback, and runbooks.

**Repository:** https://github.com/btilki/micser-apps-Azure-Terraform-Helm-GitOps-monitoring  

Corrections welcome in GitHub issues—I keep `DEPLOYMENT.md` and the phase guides aligned with what actually works in a fresh fork.

---

*Part 3 Preview: promote-to-stage and promote-to-prod pipelines, environment approvals, CODEOWNERS on prod paths, manual Sync, and rehearsed GitOps rollback.*
