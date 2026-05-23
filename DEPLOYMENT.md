# Deployment

Operator guide: clone this repository, configure Azure and Azure DevOps, deploy infrastructure, bootstrap the cluster, run CI, and promote releases through stage and prod.

Architecture context: [ARCHITECTURE.md](ARCHITECTURE.md). Security controls: [SECURITY.md](SECURITY.md). Incidents: [TROUBLESHOOTING.md](TROUBLESHOOTING.md).

---

## Prerequisites

Install and verify:

```bash
terraform version
az version
kubectl version --client
helm version
git --version
```

Tools and accounts: [README.md — Prerequisites](README.md#prerequisites).

---

## Fork setup (replace placeholders)

**Canonical GitHub remote:** `https://github.com/btilki/micser-apps-Azure-Terraform-Helm-GitOps-monitoring.git`

If you fork or rename the repo, update:

1. **GitOps** — `repoURL` in `gitops/**/*.yaml` to your HTTPS clone URL.
2. **CI** — `GITHUB_REPOSITORY` in `pipelines/ci/*.yml`.
3. **Promote** — `githubRepository` in `pipelines/promote/promote-to-*.yml`.
4. **CODEOWNERS** — `@YOUR_ORG/prod-gitops-approvers` and `prod-gitops-secondary`.
5. **Platform** — `YOUR_*` in `gitops/apps/platform/external-dns/`, `cert-manager/`.
6. **Azure DevOps** — each pipeline’s **control repository** → your fork, branch `main` ([pipelines/README.md](pipelines/README.md#azure-devops-pipeline-source-after-a-github-rename)).

Find leftovers:

```bash
rg 'btilki/micser-apps-Azure-Terraform-Helm-GitOps-monitoring|YOUR_ORG' 
rg 'YOUR_TENANT_ID' gitops/apps/platform
```

---

## What is already in this repository

| Area | Shipped in repo | You configure / run |
|------|-----------------|---------------------|
| Terraform | `infra/terraform/` | `terraform.tfvars`, `backend.hcl`, `apply` |
| Helm charts (5 services) | `charts/*/` | Digests via CI/promotion |
| GitOps | `gitops/apps/**`, `gitops/envs/**` | `repoURL`, PR merge, Argo sync |
| Bootstrap | `gitops/bootstrap/applications/*.yaml` | `root-app.yaml.example` → `root-app.yaml` |
| Platform policies | `gitops/platform/{dev,stage,prod}/` | Argo sync `platform-*` apps |
| Pipelines | `pipelines/ci/`, `pipelines/promote/` | Register in Azure DevOps |
| App Dockerfiles | `apps/*/Dockerfile` | Optional real microservices-demo source |

---

## Terraform apply order

1. `infra/terraform/envs/bootstrap` — remote state (once per subscription).
2. `infra/terraform/envs/shared` — network, DNS, AKS, ingress IP.
3. `infra/terraform/envs/dev`, `stage`, `prod` — env RG, ACR, Key Vault.

Copy `*.tfvars.example` → `terraform.tfvars` and `backend.hcl.example` → `backend.hcl`. Details: [Phase 1](docs/implementation/phase-01-terraform-foundation.md).

---

## Phased deployment guide

Work in order **0 → 9**. Each phase: goal, commands, validation checklist.

| Phase | Guide | Focus |
|-------|-------|--------|
| 0 | [Repo scaffolding](docs/implementation/phase-00-repo-scaffolding.md) | Remote, branch protection, CODEOWNERS |
| 1 | [Terraform foundation](docs/implementation/phase-01-terraform-foundation.md) | State, shared stack, env stacks |
| 2 | [Cluster bootstrap](docs/implementation/phase-02-cluster-bootstrap.md) | Ingress, cert-manager, external-dns, monitoring, Argo CD |
| 3 | [First service — frontend](docs/implementation/phase-03-first-service-frontend.md) | Register CI, dev HTTPS |
| 4 | [Promotion pipeline](docs/implementation/phase-04-promotion-pipeline.md) | `az acr import`, GitOps PRs |
| 5 | [Fan-out services](docs/implementation/phase-05-fan-out-services.md) | Remaining CI pipelines |
| 6 | [Stage environment](docs/implementation/phase-06-stage-environment.md) | Stage promote and validate |
| 7 | [Prod environment](docs/implementation/phase-07-prod-environment.md) | Manual Argo sync, alerts, prod promote |
| 8 | [Hardening](docs/implementation/phase-08-hardening.md) | Policies, Trivy, budgets |
| 9 | [Polish](docs/implementation/phase-09-polish.md) | Dashboards, smoke in promote |
| 10 | [Destroy](docs/implementation/phase-10-destroy-infrastructure.md) | Optional teardown |

### Toolchain dependencies

| Layer | Tool | Depends on |
|-------|------|------------|
| Cloud | Terraform | Bootstrap state, subscription |
| Runtime | AKS | Shared stack |
| Packages | Helm `charts/` | Images in env ACR |
| Desired state | Argo CD + `gitops/` | Phase 2 platform, repo access |
| Build | Azure DevOps CI | Dev ACR, `GITHUB_TOKEN`, ARM connection |
| Promote | Promote pipelines | ACR RBAC, values files |
| TLS | cert-manager + external-dns | Azure DNS, managed identities |
| Observe | kube-prometheus-stack | Monitoring namespace |

### First hour after clone

```bash
git clone <YOUR_FORK_URL>
cd <repo-root>
rg 'YOUR_TENANT_ID|YOUR_ORG|btilki/' --glob '!*.png' | head
```

Then Phase 0, fork setup above, Phases 1–2, register CI in [Phase 3 §2](docs/implementation/phase-03-first-service-frontend.md#2-register-ci-in-azure-devops).

---

## Azure DevOps baseline

| Name | Purpose |
|------|---------|
| `promotion-azure-connection` | ARM service connection (CI + promote) |
| `variable-group-for-microservices` | Library group |
| `GITHUB_TOKEN` | Secret in group — GitOps PR creation |

Register **one pipeline per YAML** under `pipelines/ci/` and `pipelines/promote/`. CI uses `trigger: none` — run manually unless you re-enable triggers.

Details: [pipelines/README.md](pipelines/README.md), [Phase 3](docs/implementation/phase-03-first-service-frontend.md).

---

## Promotion service principal roles

Pre-check in `pipelines/templates/promote-image.yml` before `az acr import`:

| Pipeline | Source ACR | Target ACR | Reader on RGs |
|----------|------------|------------|----------------|
| `promote-to-stage.yml` | dev: **AcrPull** | stage: **AcrPull**, **AcrPush** | `rg-boutique-stage-weu`, `rg-boutique-prod-weu` |
| `promote-to-prod.yml` | stage: **AcrPull** | prod: **AcrPush** | same |

Optional Terraform: `promotion_service_principal_object_id` in env `terraform.tfvars`.

---

## Release flow

1. **CI** — build, Trivy, push **dev** ACR, open PR for `gitops/envs/dev/values-<service>.yaml`.
2. **Merge** — Argo syncs dev.
3. **Promote stage** — `promote-to-stage.yml` → import → stage values PR → merge → Argo syncs stage → smoke (if configured).
4. **Promote prod** — `promote-to-prod.yml` → approval → prod values PR → merge → **manual** Argo sync for prod apps.
5. Verify — [release-verification](docs/runbooks/release-verification.md).

---

## Environment URLs (defaults)

Replace `example.com` with your domain:

| Env | Storefront |
|-----|------------|
| dev | `https://dev.boutique.example.com` |
| stage | `https://stage.boutique.example.com` |
| prod | `https://boutique.example.com` |

Operations: Argo CD `https://argocd.example.com`, Grafana `https://grafana.example.com` (configure per your ingress).

Prod GitOps: [prod-branch-protection](docs/gitops/prod-branch-protection.md), [prod-known-good-digests](docs/gitops/prod-known-good-digests.md). Other component paths: [README — Repository layout](README.md#repository-layout).
