# Online Boutique on Azure

Mono-repo for Google’s [microservices-demo](https://github.com/GoogleCloudPlatform/microservices-demo) on **Azure Kubernetes Service (AKS)** with **Terraform**, **Azure DevOps** CI/CD, **Argo CD** GitOps, and **kube-prometheus-stack** observability.

## System overview

**Goal:** Reproducible infrastructure (Terraform), push-to-dev CI, pull-based GitOps CD, **build once — promote by immutable digest** across per-environment Azure Container Registries (`az acr import`), HTTPS (NGINX Ingress + cert-manager + Azure DNS), secrets via **Key Vault + CSI driver**, metrics/alerts in **Prometheus / Grafana / Alertmanager**.

**Topology:** One AKS cluster (typical layout in this repo), logical environments **dev / stage / prod** isolated with namespaces, quotas, network policies, and separate ACR + Key Vault per environment.

### v1 application scope (this repository)

| Track | Workloads | Images / CI |
| --- | --- | --- |
| **Owned here** | `frontend`, `cartservice`, `currencyservice`, `productcatalogservice`, `redis-cart` | Built in Azure DevOps, scanned (Trivy), pushed to env ACRs; Helm under `charts/`; GitOps under `gitops/` |
| **Upstream demo (optional full path)** | `checkoutservice`, `emailservice`, `paymentservice`, `shippingservice`, `recommendationservice`, `loadgenerator` | Published images from [microservices-demo](https://github.com/GoogleCloudPlatform/microservices-demo); not built by this repo’s service CI |
| **Optional later** | `adservice`, other demo services | Same upstream-image pattern or add chart + CI like owned services |

**End-to-end flow:** Developer → GitHub → Azure DevOps (build/scan → dev ACR; promotion pipelines import digest to stage/prod ACR and open GitOps PRs) → merge → Argo CD reconciles cluster state from Git.

### Diagrams (PNG exports)

- [Platform overview](docs/diagrams/00-platform-overview.png)
- [CI/CD flow](docs/diagrams/01-cicd-flow.png)
- [Azure resources](docs/diagrams/02-azure-resources.png)
- [Inside cluster](docs/diagrams/03-inside-cluster.png)

## Documentation map

| Topic | Where |
| --- | --- |
| **Step-by-step build (phases 0–10)** | [docs/implementation/README.md](docs/implementation/README.md) |
| **Operations / incidents** | [docs/runbooks/README.md](docs/runbooks/README.md) |
| **Prod GitOps approvals & known-good digests** | [docs/gitops/prod-branch-protection.md](docs/gitops/prod-branch-protection.md), [docs/gitops/prod-known-good-digests.md](docs/gitops/prod-known-good-digests.md) |
| **Azure Pipelines** | [pipelines/README.md](pipelines/README.md) |
| **GitOps tree layout** | [gitops/README.md](gitops/README.md), [gitops/bootstrap/applications/README.md](gitops/bootstrap/applications/README.md) |
| **Helm charts** | [charts/README.md](charts/README.md) |
| **Service sources** | [apps/README.md](apps/README.md) |
| **Smoke / scripts** | [scripts/README.md](scripts/README.md) |
| **Policy bundles (Kyverno / Gatekeeper)** | [policies/README.md](policies/README.md) |
| **Terraform state bootstrap** | [infra/terraform/envs/bootstrap/README.md](infra/terraform/envs/bootstrap/README.md) |

## Layout

| Path | Purpose |
|------|---------|
| `infra/terraform/` | Modules and environment roots (`bootstrap`, `shared`, `dev`, `stage`, `prod`) |
| `gitops/` | Argo CD app-of-apps (`bootstrap/`) and `apps/` + `envs/` per environment |
| `pipelines/` | Azure DevOps YAML: `ci/`, `promote/`, `templates/` |
| `charts/` | Helm charts per microservice; `_common/` for shared helpers |
| `apps/` | Microservice source (subset aligned with microservices-demo) |
| `scripts/` | Smoke tests and local automation |
| `policies/` | NetworkPolicies, PDBs, optional Kyverno/Gatekeeper |
| `docs/implementation/` | Phased implementation guides |
| `docs/runbooks/` | Operational procedures |
| `docs/gitops/` | Prod GitOps process notes |
| `docs/diagrams/` | Architecture diagram PNG exports |
| `azure-pipelines.yml` | Optional manual pipeline: verifies expected YAML under `pipelines/ci/` and `pipelines/promote/`; register one ADO pipeline per file there for real CI and promotions |

## Fork setup (replace placeholders)

**Canonical GitHub remote:** `https://github.com/btilki/microservice-apps-on-azure-using-terraform-helm-gitops-and-observability.git`  
Argo CD `repoURL` values and Azure DevOps `GITHUB_REPOSITORY` / `githubRepository` defaults already use `btilki/microservice-apps-on-azure-using-terraform-helm-gitops-and-observability`. If you **fork** or copy under another org or repo name, search-replace that `org/repo` string (and the matching `https://github.com/...git` URLs) everywhere below.

1. **GitOps** — In `gitops/**/*.yaml`, every `repoURL` (and `sources` URLs on `Application`/`AppProject` objects) should match your clone’s HTTPS URL (same string everywhere is fine).
2. **CI pipelines** — In `pipelines/ci/*.yml`, set `GITHUB_REPOSITORY` to `your-org/your-repo` so PR API calls target the correct GitHub repository.
3. **Promotion pipelines** — In `pipelines/promote/promote-to-stage.yml` and `promote-to-prod.yml`, set the `githubRepository` parameter default to the same slug (the template `pipelines/templates/promote-image.yml` consumes this value).
4. **`CODEOWNERS`** — Replace `@YOUR_ORG/prod-gitops-approvers` and `@YOUR_ORG/prod-gitops-secondary` with teams (or users) that should own production GitOps paths.
5. **Azure platform GitOps** — In `gitops/apps/platform/external-dns/azure.json`, `gitops/apps/platform/external-dns/values.yaml`, `gitops/apps/platform/cert-manager/clusterissuer.yaml`, and `gitops/apps/platform/cert-manager/values.yaml`, replace `YOUR_TENANT_ID`, `YOUR_SUBSCRIPTION_ID`, `YOUR_DNS_RESOURCE_GROUP`, managed identity client IDs, DNS zone name, and ACME email with your values (for example from `az account show`, `az identity show`, and Terraform outputs described in [Phase 1](docs/implementation/phase-01-terraform-foundation.md) / [Phase 2](docs/implementation/phase-02-cluster-bootstrap.md)).

To catch any remaining canonical slug or `YOUR_ORG` team placeholders (including under `docs/`), run `rg 'btilki/microservice-apps-on-azure-using-terraform-helm-gitops-and-observability|YOUR_ORG'` from the repo root; for Azure placeholders, run `rg YOUR_TENANT_ID gitops/apps/platform` (and similarly for other `YOUR_*` strings above). Adjust matches you intend to keep literal.

## Terraform apply order

1. `infra/terraform/envs/bootstrap` — remote state storage (once per subscription/tenant setup).
2. `infra/terraform/envs/shared` — network, Log Analytics, DNS zone, AKS, ingress public IP.
3. `infra/terraform/envs/dev`, `stage`, `prod` — environment resource groups, ACR, Key Vault, private endpoints, kubelet `AcrPull`.

Copy `*.tfvars.example` to `terraform.tfvars` and configure the Azure backend per `backend.hcl.example`.

## Promotion SP role control

Promotion pipelines include a fail-fast permission gate in `pipelines/templates/promote-image.yml` (`Validate service principal role assignments` step).  
The check runs before `az acr import` and PR creation, and validates role assignments for the service principal behind `promotion-azure-connection`.

Required assignments:

- Stage promotions (`promote-to-stage.yml`):
  - Source ACR (dev): `AcrPull`
  - Target ACR (stage): `AcrPull`, `AcrPush`
- Prod promotions (`promote-to-prod.yml`):
  - Source ACR (stage): `AcrPull`
  - Target ACR (prod): `AcrPush`
- Reader scopes (all promotion pipelines):
  - `rg-boutique-stage-weu`: `Reader`
  - `rg-boutique-prod-weu`: `Reader`

If any required role is missing, the pipeline stops before image promotion.

## Current Azure DevOps baseline

Current repository pipelines are aligned to the following Azure DevOps names:

- ARM service connection: `promotion-azure-connection`
- Variable group: `variable-group-for-microservices`
- GitHub secret variable: `GITHUB_TOKEN`

See [pipelines/README.md](pipelines/README.md) for pipeline-specific details.

## Release flow (concise)

1. **CI** (`pipelines/ci/*.yml`) builds, scans (Trivy), pushes to **dev ACR**, and may open a PR to bump the dev image digest in GitOps.
2. **Promote to stage** (`pipelines/promote/promote-to-stage.yml`): pick `service`, optional digest override → `az acr import` dev→stage ACR → update `gitops/envs/stage/values-*.yaml` → **smoke test** stage storefront → open GitHub PR to `main`.
3. Merge the PR → **Argo CD** syncs stage workloads.
4. **Promote to prod** (`pipelines/promote/promote-to-prod.yml`): same pattern from stage→prod with approvals on the `promote-prod` environment.
5. Post-merge checks: [docs/runbooks/release-verification.md](docs/runbooks/release-verification.md).

## Operations quickstart

- Argo CD UI: `https://argocd.example.com`
- Grafana UI: `https://grafana.example.com`
- Runbooks index: [docs/runbooks/README.md](docs/runbooks/README.md)
- Core runbooks:
  - [Prod rollback](docs/runbooks/prod-rollback.md)
  - [Ingress 5xx triage](docs/runbooks/ingress-5xx-triage.md)
  - [Certificate renewal/expiry](docs/runbooks/certificate-renewal-expiry.md)
  - [Failing Argo CD sync in prod](docs/runbooks/failing-argocd-sync-prod.md)
- Promotion pipelines:
  - `pipelines/promote/promote-to-stage.yml`
  - `pipelines/promote/promote-to-prod.yml`
- Environment hosts:
  - Dev storefront: `https://dev.boutique.example.com`
  - Stage storefront: `https://stage.boutique.example.com`
  - Prod storefront: `https://boutique.example.com`

## Next steps

1. Create the **Git** remote and **Azure DevOps** project; push this repo (see [pipelines/README.md](pipelines/README.md)).
2. Follow [docs/implementation/README.md](docs/implementation/README.md) starting at **Phase 0** (branch protection) and **Phase 1** (Terraform).
3. Wire **Argo CD** using `gitops/bootstrap/root-app.yaml.example` and connect **service connections** (Workload Identity Federation) as described in the implementation phases and [gitops/README.md](gitops/README.md).
