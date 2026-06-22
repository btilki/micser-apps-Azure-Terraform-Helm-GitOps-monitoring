# CI/CD Pipeline Project — Google Microservices Demo on Azure

**Owner:** *(your name — set when you fork this repo)*
**Created:** 2026-05-03
**Stack:** GitHub · Azure Container Registry · Azure DevOps · Azure Kubernetes Service · Terraform · Helm · ArgoCD · NGINX Ingress · cert-manager · Prometheus · Grafana
**Target app:** Google's Online Boutique (microservices-demo) — 11 polyglot services + Redis
**Environments:** dev · stage · prod

### v1 scope (explicit)

This project’s **first delivery (v1)** does **not** build every demo microservice in Azure DevOps.

| Track | Workloads | Images / CI |
| --- | --- | --- |
| **Owned in this repo (v1)** | **5 owned workloads = 4 microservices + Redis:** `frontend`, `cartservice`, `currencyservice`, `productcatalogservice`, `redis-cart` | Built by this repo’s pipelines, stored in environment ACRs, deployed via Helm charts under `charts/` (aligned with Google’s Online Boutique; no separate “backend” service) |
| **Upstream Google demo** | **5 microservices** — `checkoutservice`, `emailservice`, `paymentservice`, `shippingservice`, `recommendationservice` — plus **`loadgenerator`** | Use published images from the [microservices-demo](https://github.com/GoogleCloudPlatform/microservices-demo) project (e.g. deploy alongside in a namespace such as `google-boutique`; not built or promoted by this repo’s service CI) |

**Not in v1 upstream slice:** `adservice` (and any other demo services not listed above) can be added later using the same upstream-image pattern.

---

## How to use this document

This is a living planning doc. The phases below are the recommended execution order. The **Decisions to make** section at the bottom is where you should fill in answers — those choices drive the rest of the implementation.

---

## Phase 1 — Plan & gather requirements

Decide the boundaries before designing anything:

- **Environments**: dev / stage / prod — same cluster with namespaces, or one AKS cluster per env? (cost vs. blast-radius trade-off)
- **Region(s)** and HA target (single region multi-AZ is usually right for a demo)
- **Domain & DNS**: do you own a domain you can delegate to Azure DNS? You'll need one for HTTPS via Let's Encrypt
- **Naming & tagging convention** (e.g. `rg-boutique-dev-weu`, `aks-boutique-prod-weu`)
- **Branching/promotion model**: trunk-based with env folders in a GitOps repo is the cleanest fit for ArgoCD
- **Image registry layout**: one shared ACR with repo-level RBAC, or one ACR per env

**Deliverable:** 1-page requirements doc + high-level architecture diagram.

---

## Phase 2 — Architecture design

Sketch the target state. Key decisions:

- **Repos**: at least two — an *app/infra* repo and a *GitOps config* repo (ArgoCD watches the second)
- **AKS topology**: baseline `system + user` node pools (autoscaler on), Azure CNI overlay, Workload Identity enabled; optional env-tainted pools (`npdev`, `npstg`, `npprod`) can be enabled later
- **Networking**: VNet with subnets for AKS, AppGw/ingress, and private endpoints; NSGs; private ACR via private endpoint
- **Identity**: Azure AD-integrated AKS, Workload Identity for pod-to-Azure auth, ACR pulled via managed identity (no image-pull secrets)
- **Secrets**: Azure Key Vault + CSI Secrets Store driver, never secrets in Git
- **Ingress**: NGINX Ingress Controller (simpler) or Application Gateway Ingress Controller (more Azure-native). For this scope I'd pick NGINX
- **TLS**: cert-manager + Let's Encrypt (DNS-01 challenge against Azure DNS) — gives you wildcard certs per env
- **Monitoring**: kube-prometheus-stack (Prometheus, Alertmanager, Grafana, node-exporter, kube-state-metrics) installed via Helm and managed by ArgoCD
- **GitOps pattern**: ArgoCD "app-of-apps" — one root Application per env that fans out to all microservices + platform components

**Deliverable:** architecture diagram + ADRs for the 4–5 contentious choices.

---

## Phase 3 — Infrastructure as Code (Terraform)

Lay down the cloud foundation. Module structure:

- `modules/` — `network`, `aks`, `acr`, `keyvault`, `log_analytics`, `dns`
- `envs/dev`, `envs/stage`, `envs/prod` — each with its own `terraform.tfvars` and remote state
- **Backend:** Azure Storage account with state locking, separate container per env
- **Outputs:** kubeconfig, ACR login server, KV URI — consumed by the pipeline

**Run order:** network → ACR/KV/LA → AKS → DNS records.

---

## Phase 4 — Bootstrap the cluster (platform layer)

After Terraform creates AKS, install the platform components — ideally also via Terraform's Helm provider so it's reproducible:

1. ArgoCD itself (chicken-and-egg: install it once, then have it manage itself)
2. NGINX Ingress Controller
3. cert-manager + ClusterIssuer for Let's Encrypt
4. external-dns (optional, automates A-record creation)
5. kube-prometheus-stack
6. Secrets Store CSI driver + Azure provider

After this, ArgoCD takes over and everything else flows through Git.

---

## Phase 5 — Helm charts for the application

Two options:

- **(a)** umbrella Helm chart with one sub-chart per microservice
- **(b)** one chart with parameterized templates per service

Recommendation: **one chart per service** (cleaner ownership) plus an umbrella App-of-Apps in the GitOps repo.

Each chart should include: Deployment, Service, HPA, PDB, NetworkPolicy, ServiceAccount, and (for the frontend) an Ingress with TLS. Values files per environment override replicas, resources, image digest, and hostnames.

### Scope (v1)

The repo owns charts + CI for **5 services**: `frontend`, `cartservice`, `productcatalogservice`, `currencyservice`, and `redis-cart`. Additional Online Boutique services (`checkoutservice`, `paymentservice`, `shippingservice`, `emailservice`, `recommendationservice`, `adservice`) and `loadgenerator` can use Google's upstream container images via overlay-only Helm values — no in-tree Dockerfile or CI pipeline. Adopting them in-tree later means duplicating the pattern of an in-tree service: `apps/<svc>/Dockerfile` + `charts/<svc>/` + `pipelines/ci/<svc>.yml` + `gitops/apps/<env>/<svc>.yaml`.

---

## Phase 6 — CI pipeline (Azure DevOps)

For each microservice, the CI pipeline does:

1. Checkout, lint, unit test
2. Build container image, tag with `${git-sha}` and `${branch}`
3. Scan with Trivy (or Defender for Containers)
4. Push to ACR
5. **Update the GitOps repo** — bump the image **digest** in `gitops/envs/dev/values-*.yaml` via a PR (this is what triggers deployment)

Use a multi-stage YAML pipeline, templates for shared steps, and service connections with workload identity federation (no PATs).

---

## Phase 7 — CD pipeline (ArgoCD GitOps)

ArgoCD watches the GitOps repo. Promotion is just a git operation:

- **Dev:** auto-sync, auto-prune, self-heal — every commit lands instantly
- **Stage:** auto-sync but require PR approval to merge into `envs/stage/`
- **Prod:** manual sync, plus PR approval and protected branch — promote by copying tested values from stage to prod

The "app-of-apps" root manages: platform charts (ingress, cert-manager, prometheus) + each microservice Application.

---

## Phase 8 — Ingress, DNS, and HTTPS

- Wildcard DNS per env: `*.dev.example.com`, `*.stage.example.com`, `*.example.com`
- cert-manager issues certs via DNS-01 against Azure DNS
- NGINX Ingress terminates TLS, routes `frontend.<env>.example.com` to the boutique frontend service

---

## Phase 9 — Monitoring & observability

- Prometheus scrapes all services (the demo app exposes metrics)
- Grafana with dashboards: cluster health, per-service RED metrics, ingress latency
- Alertmanager rules for pod crashloops, high error rate, cert expiry
- Optional but cheap wins: Loki for logs, Tempo for traces (the demo app already emits OpenTelemetry)

---

## Phase 10 — Security hardening

- NetworkPolicies (default-deny, then allow per service)
- Pod Security Standards: `restricted` in prod
- Image signing with cosign + Kyverno/Gatekeeper policy to enforce
- Secrets exclusively from Key Vault via CSI
- ACR content trust + vulnerability scanning gates in CI

---

## Phase 11 — Validate, document, harden

- Smoke tests after each deploy (curl the frontend, check 200) — *scripts/ folder pending*
- Load test in stage (k6 or Locust)
- Runbooks for common failures — ✅ shipped: `docs/runbooks/{certificate-renewal-expiry,failing-argocd-sync-prod,ingress-5xx-triage,prod-rollback}.md`
- Cost review (AKS + LA + ACR add up fast)
- Disaster recovery: how do you rebuild this from scratch? (Terraform + GitOps repo should be enough)
- **Grafana dashboards as JSON in repo** — *pending; scoped to a Phase 9.1 follow-up rather than blocking initial release. Default kube-prometheus-stack dashboards cover the day-one needs.*

---

## Phase 12 — Decommissioning / teardown

The destroy order matters as much as the build order. Going in the wrong order leaves orphaned resources that keep billing.

Reverse-of-build order:

1. **Stop ingress traffic.** Delete (or de-delegate) DNS records for `*.boutique.example.com`. Users see clean failures rather than 5xx.
2. **App layer.** Delete ArgoCD `Application`s in order **prod → stage → dev**. This drains pods and releases LoadBalancer/Public-IP allocations.
3. **Platform layer.** Delete kube-prometheus-stack, cert-manager (revoke or let pending certs expire), external-dns, NGINX Ingress, then ArgoCD itself.
4. **K8s namespaces.** Delete `dev`, `stage`, `prod`, and platform namespaces. Wait for finalizers.
5. **Federated identity credentials.** Remove federated credentials from each UAMI before destroying AKS — otherwise they orphan when the OIDC issuer disappears.
6. **Env stacks.** `terraform destroy` on `prod`, then `stage`, then `dev`. Each removes that env's ACR + Key Vault + RG.
   - **Watch out:** prod Key Vault has `purge_protection_enabled = true`. TF can soft-delete it but cannot purge — it sits for 90 days.
7. **Shared stack.** `terraform destroy` on `envs/shared`. TF dependency graph handles AKS → LA → DNS zone → public IP → VNet → private DNS zones → shared RG.
8. **Bootstrap stack.** `terraform destroy` on `envs/bootstrap` to delete the state storage account. **This is irreversible — you lose all TF history.**
9. **Soft-delete cleanup.**
   - `az keyvault list-deleted` then `az keyvault purge --name <kv>` for non-prod vaults.
   - Prod vault stays soft-deleted for the retention window.
   - Storage account soft-delete sits for its retention period.
10. **Registrar revert.** At your domain registrar, switch `example.com` NS records away from Azure DNS.
11. **Outside-Azure cleanup.** Delete Azure DevOps service connections, pipelines, federated identity federations, environments. Archive/delete the GitHub repo. Remove AAD groups created for this project. Disable the Azure Budget alert.

**Validation after teardown:**

- `az resource list --tag project=boutique` returns empty.
- `az keyvault list-deleted` returns empty (after purge window).
- Azure portal cost view drops to ~$0 within 24h.
- Registrar shows non-Azure NS records.

**Non-destructive "scale to zero" alternative.** If you want to pause without destroying:

- `az aks stop --name aks-boutique-weu` — pauses the cluster, no VM cost, control plane is free.
- ACR/KV/LA still bill (~$60/mo total).
- `az aks start` to resume.

---

## Suggested execution order

Bottom-up vertical slice:

1. Terraform foundation
2. Bootstrap ArgoCD
3. Wire **one** microservice end-to-end through CI/CD
4. Fan out **owned v1 services** (four microservices + Redis per **v1 scope** above); run the **five upstream services + loadgenerator** from Google’s images where needed for a full storefront path
5. Add monitoring / ingress / TLS
6. Harden security
7. Promote through environments
8. (When done with the project) **Teardown** — Phase 12 above

Getting one service fully working before scaling out saves a lot of debugging pain.

---

## Decisions to make (please fill in)

These choices drive the rest of the implementation. Edit your answers under each question.

### 1. Cluster topology
> One AKS cluster with dev/stage/prod namespaces, or one cluster per environment?

**Answer:**One AKS cluster with dev/stage/prod namespaces

---

### 2. Domain
> Do you have a real domain you can use for HTTPS, or should we assume a placeholder like `boutique.example.com`?

**Answer:** Use a dedicated DNS zone you control (for demos, `example.com`-style delegated zones are fine). Point cert-manager DNS-01 and ingress hostnames at that zone.

---

### 3. Repo layout
> Single mono-repo, or split app + gitops + infra into separate repos?

**Answer:**Single mono-repo

---

### 4. Azure region
> Preferred Azure region (e.g. West Europe, East US, North Europe)?

**Answer:**West Europe

---

### 5. Scope of first deliverable
> Full architecture/design doc first, or jump straight into Terraform + a single working microservice as a vertical slice?

**Answer:**Full architecture/design doc first

---

### 6. Image registry layout
> One shared ACR with repo-level RBAC, or one ACR per environment?

**Answer:** one ACR per environment

---

### 7. Ingress controller
> NGINX Ingress (simpler, portable) or Application Gateway Ingress Controller (more Azure-native, costs more)?

**Answer:** NGINX Ingress (simpler, portable)

---

### 8. Secret management
> Azure Key Vault + CSI driver (recommended), or sealed-secrets / SOPS-encrypted in Git?

**Answer:** Azure Key Vault + CSI driver (recommended)

---

### 9. Promotion model
> Auto-sync to dev, manual approval to stage and prod? Or stricter (manual to all)?

**Answer:** Auto-sync to dev, manual approval to stage and prod

---

### 10. Budget / scale targets
> Any budget cap or specific node count / replica targets per environment?

**Answer:**
- **Budget cap:** ~$500/month at list price (Azure Budget alert at 80%).
- **Node counts (autoscaler):**
  - `system` pool: D2s_v5 × 2 min / 3 max
  - `npdev`: B2s × 1 min / 3 max
  - `npstg`: D2s_v5 × 1 min / 3 max
  - `npprod`: D2s_v5 × 2 min / 4 max (zones 1, 2, 3)
- **Replicas (per service):** dev 1 · stage 2 · prod 2 (HA). `frontend` prod 3 for spare capacity.
- **Cost levers if cap is exceeded:** flip user pools to `Standard_B2s`, scale dev to 0 outside work hours, drop one PE if accepting public ACR access from non-prod, reduce LA daily ingestion quota.

---

## Notes & follow-ups

(Use this space for anything that comes up while answering.)

