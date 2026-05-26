# Medium draft — Part 2 of 3

**Suggested title:** From Clone to HTTPS: Deploying Online Boutique on Azure (Terraform, AKS, and Your First Pipeline)  
**Subtitle:** Part 2 of 3 — Bootstrap state, install the platform stack, register Azure DevOps CI, and open the dev storefront  
**Tags (pick 5):** Azure, Kubernetes, Terraform, AKS, Helm, Argo CD, DevOps, Tutorial  
**Repo link (use in story):** https://github.com/btilki/micser-apps-Azure-Terraform-Helm-GitOps-monitoring  

**Images to upload to Medium (from repo `docs/diagrams/`):**  
1. `02-azure-resources.png` — after Terraform section  
2. `03-inside-cluster.png` — after cluster bootstrap  
3. `01-cicd-flow.png` — in “First CI run” section  
4. Optional (Azure DevOps UI): `docs/diagrams/azure-devops-settings-service-connections.png`, `azure-devops-library-variable-group-github-token.png`  

---

*Part 2 of 3. [Part 1](post-01-architecture-and-choices.md) explained the design. Here we deploy. [Part 3](post-03-promote-prod-and-operations.md) covers stage/prod promotion and day-two operations.*

---

In [Part 1](https://github.com/btilki/micser-apps-Azure-Terraform-Helm-GitOps-monitoring/blob/main/docs/medium/post-01-architecture-and-choices.md) I described *why* this platform uses one AKS cluster, three container registries, and GitOps-by-digest. This article is the hands-on path: clone the repo, lay down Azure with Terraform, bootstrap ingress and Argo CD, and run the **frontend** CI pipeline until `https://dev.boutique.<your-domain>` answers.

The repository already contains charts, GitOps manifests, and pipeline YAML—you configure identities and run the phases in order.

**Repository:** https://github.com/btilki/micser-apps-Azure-Terraform-Helm-GitOps-monitoring  

Detailed checklists live in `DEPLOYMENT.md` and `docs/implementation/phase-*.md`. I summarize the spine here so you can publish or follow without opening ten files at once.

---

## Before you start

Install and verify:

```bash
terraform version
az version
kubectl version --client
helm version
git --version
```

You need an Azure subscription, permission to create resource groups and AKS, a DNS zone you control (for TLS via DNS-01), GitHub (for GitOps PRs from pipelines), and an Azure DevOps project (for CI). Pipelines use **manual** triggers by default—good while learning.

**Fork setup:** If you fork the repo, replace placeholders for `repoURL` in GitOps, `GITHUB_REPOSITORY` in CI YAML, `githubRepository` in promote YAML, `YOUR_ORG` in CODEOWNERS, and tenant/DNS IDs in platform apps. The repo documents search commands:

```bash
rg 'btilki/micser-apps-Azure-Terraform-Helm-GitOps-monitoring|YOUR_ORG'
rg 'YOUR_TENANT_ID' gitops/apps/platform
```

---

## Phase map (what you will run)

| Order | Focus | Outcome |
|-------|--------|---------|
| 0 | Repo scaffolding | Branch protection, CODEOWNERS |
| 1 | Terraform | State, VNet, AKS, per-env ACR and Key Vault |
| 2 | Cluster bootstrap | Ingress, cert-manager, external-dns, monitoring, Argo CD |
| 3 | First service | Register `pipelines/ci/frontend.yml`, merge digest PR, HTTPS dev URL |

Phases 4–7 (promotion, stage, prod) are [Part 3](post-03-promote-prod-and-operations.md).

---

## Terraform: bootstrap → shared → environments

Apply in this order only:

1. **`infra/terraform/envs/bootstrap`** — remote state storage (once per subscription).
2. **`infra/terraform/envs/shared`** — VNet, Log Analytics, public DNS zone, AKS `aks-boutique-weu`, static ingress IP.
3. **`infra/terraform/envs/dev`** (then stage/prod when ready) — environment resource group, dedicated ACR, Key Vault.

Copy each stack’s `*.tfvars.example` → `terraform.tfvars` and `backend.hcl.example` → `backend.hcl` before `terraform init` and `apply`.

**[Insert image: 02-azure-resources.png — caption: Bootstrap state, shared platform, and per-environment registries.]**

Why three applies? Blast radius and permissions: shared infrastructure is long-lived; env stacks can be destroyed or recreated without touching the cluster definition. The dev ACR name in the reference layout is **`acrboutiquedevweu`**—your kubelet identity will need **AcrPull** on it after you attach the registry to AKS.

After Phase 1, capture outputs:

```bash
cd infra/terraform/envs/dev && terraform output
```

You will need ACR login server, resource group names, and Key Vault URIs in later steps.

---

## Cluster bootstrap: platform before apps

With `kubectl` pointed at the cluster, install the shared platform (Phase 2 guide):

- **ingress-nginx** — HTTP(S) entry; ties to the Terraform static IP.
- **cert-manager** — certificates via **DNS-01** against Azure DNS (Workload Identity, no long-lived cloud secrets in Git).
- **external-dns** — records aligned with Ingress hosts.
- **kube-prometheus-stack** — Prometheus, Grafana, Alertmanager in `monitoring`.
- **Argo CD** — GitOps controller; app-of-apps from `gitops/bootstrap/`.

**[Insert image: 03-inside-cluster.png — caption: Platform namespaces and app namespaces on one cluster.]**

Copy `gitops/bootstrap/applications/root-app.yaml.example` to `root-app.yaml` with your Git URL, commit, and let Argo CD sync the bootstrap Applications. You should see platform apps (ingress, cert-manager, etc.) and umbrella apps for `dev` before any boutique workload is healthy.

Sanity checks:

```bash
kubectl get nodes
kubectl get applications -n argocd
kubectl get pods -n ingress-nginx,cert-manager,argocd
```

Do not skip platform sync—frontend TLS depends on cert-manager and external-dns being healthy.

---

## Azure DevOps: connections the pipelines expect

Register once per project:

| Name | Purpose |
|------|---------|
| `promotion-azure-connection` | ARM service connection for `AzureCLI@2` (build, push, `az acr import`) |
| `variable-group-for-microservices` | Library group holding secrets |
| `GITHUB_TOKEN` | Secret in the group — opens GitOps digest PRs on GitHub |

**[Optional: insert azure-devops-settings-service-connections.png and azure-devops-library-variable-group-github-token.png.]**

The promotion service principal needs **AcrPush** on dev ACR for CI; promote pipelines add **AcrPull**/**AcrPush** on stage/prod registries (see `DEPLOYMENT.md` — Promotion SP roles). The shared template `pipelines/templates/promote-image.yml` fails fast if RBAC is wrong—fix roles before blaming import.

---

## First CI run: frontend to dev

The repo already ships:

| Artifact | Path |
|----------|------|
| Helm chart | `charts/frontend/` |
| Dev Application | `gitops/apps/dev/` (via umbrella `apps-dev`) |
| Dev values (digest updated by CI) | `gitops/envs/dev/values-frontend.yaml` |
| CI pipeline | `pipelines/ci/frontend.yml` |
| Dockerfile | `apps/frontend/Dockerfile` |

**Register the pipeline:** In Azure DevOps → **Pipelines** → **New pipeline** → GitHub → your fork → **Existing Azure Pipelines YAML file** → path `/pipelines/ci/frontend.yml`. Triggers are off; click **Run pipeline** when ready.

**What one run does:**

1. Builds and pushes an image to **dev ACR**.
2. Scans with **Trivy** (fails on high/critical).
3. Opens a GitHub PR updating `image.digest` in `gitops/envs/dev/values-frontend.yaml`.

**[Insert image: 01-cicd-flow.png — caption: CI builds to dev ACR; merge the GitOps PR; Argo CD deploys to the dev namespace.]**

Set `ingress.host` in dev values to your hostname (e.g. `dev.boutique.example.com`). Keep `googleDemo.enabled: false` when using your own image—otherwise the chart can route to upstream ExternalName services you have not deployed and return **503**.

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

## Fan-out (same pattern, more services)

v1 builds five owned workloads: **frontend**, **cartservice**, **currencyservice**, **productcatalogservice**, **redis-cart**. Each has `pipelines/ci/<service>.yml`, a chart under `charts/`, and values under `gitops/envs/dev/`. Register one Azure DevOps pipeline per YAML—the mechanics are identical to frontend.

Upstream Google images (checkout, payment, email, etc.) can be enabled later for the full demo journey without this repo rebuilding them.

---

## When something fails

| Symptom | First look |
|---------|------------|
| Pipeline cannot push to ACR | SP roles on dev ACR; service connection subscription |
| No GitOps PR | `GITHUB_TOKEN` in variable group; `GITHUB_REPOSITORY` in YAML |
| Certificate pending | DNS zone IDs in cert-manager/external-dns; Workload Identity |
| 503 on storefront | `googleDemo.enabled`, pod logs, Ingress backend |
| Argo OutOfSync | Diff in values; manual sync on dev if needed |

Full index: `TROUBLESHOOTING.md` and `docs/runbooks/`.

---

## What you should have now

- Terraform-managed Azure foundation and **dev** ACR with at least one image.
- Platform controllers and Argo CD reconciling from Git.
- A merged digest PR and a **HTTPS** dev storefront URL.
- Confidence that the next move is **promotion**, not rebuilding for stage.

---

## Next

[Part 3](post-03-promote-prod-and-operations.md): `az acr import` to stage and prod, manual prod Argo sync, alerts, rollback, and runbooks.

**Repository:** https://github.com/btilki/micser-apps-Azure-Terraform-Helm-GitOps-monitoring  

Corrections welcome in GitHub issues—I keep `DEPLOYMENT.md` and the phase guides aligned with what actually works in a fresh fork.

---

*Part 3 preview: promote-to-stage and promote-to-prod pipelines, environment approvals, CODEOWNERS on prod paths, manual Sync, and rehearsed GitOps rollback.*
