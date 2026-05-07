# Online Boutique on Azure

Mono-repo for Google’s [microservices-demo](https://github.com/GoogleCloudPlatform/microservices-demo) on Azure Kubernetes Service, with Terraform, Azure DevOps CI/CD, and ArgoCD GitOps.

Production-grade CI/CD platform on Azure — AKS, Terraform, ArgoCD, Azure DevOps. Deploys Google's [online-boutique-microservices](https://github.com/GoogleCloudPlatform/microservices-demo) with full GitOps and observability.

## Documentation

- [Architecture & design](docs/architecture-design.md) — target state, networking, per-environment ACRs, identity, observability.
- [CI/CD pipeline plan](docs/cicd-pipeline-plan.md) — phased delivery and decisions.
- [Implementation phases](docs/implementation/README.md) — one file per phase: **Implementation** (tools/steps) + checklist; [legacy pointer](docs/implementation-guide.md).

## Layout

| Path | Purpose |
|------|---------|
| `infra/terraform/` | Modules and environment roots (`bootstrap`, `shared`, `dev`, `stage`, `prod`) |
| `gitops/` | Argo CD app-of-apps (`bootstrap/`) and `apps/` + `envs/` per environment |
| `pipelines/` | Azure DevOps YAML: `ci/`, `promote/`, `templates/` |
| `charts/` | Helm charts per microservice; `_common/` for shared helpers |
| `apps/` | Microservice source (fork/subtree of microservices-demo) |
| `policies/` | NetworkPolicies, PDBs, optional Kyverno/Gatekeeper |
| `scripts/` | Smoke tests and local automation |
| `docs/` | Architecture, CI/CD plan, implementation phases, `adr/`, `runbooks/` |
| `azure-pipelines.yml` | Default ADO entry (placeholder until real CI is wired) |

## Terraform apply order

1. `infra/terraform/envs/bootstrap` — remote state storage (once per subscription/tenant setup).
2. `infra/terraform/envs/shared` — network, Log Analytics, DNS zone, AKS, ingress public IP.
3. `infra/terraform/envs/dev`, `stage`, `prod` — environment resource groups, ACR, Key Vault, private endpoints, kubelet `AcrPull`.

Copy `*.tfvars.example` to `terraform.tfvars` and configure the Azure backend per `backend.hcl.example`.

## Promotion SP role control

Promotion pipelines now include a fail-fast permission gate in `pipelines/templates/promote-image.yml` (`Validate service principal role assignments` step).  
The check runs before `az acr import` and PR creation, and validates role assignments for the service principal behind `promotion-azure-connection`.

Required assignments:

- Stage promotions (`promote-to-stage.yml`, `promote-to-stage-backend.yml`):
  - Source ACR (dev): `AcrPull`
  - Target ACR (stage): `AcrPull`, `AcrPush`
- Prod promotions (`promote-to-prod.yml`, `promote-to-prod-backend.yml`):
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

See `pipelines/README.md` for pipeline-specific details.

## Next steps

1. Create the **Git** remote and **Azure DevOps** project; push this repo (see `pipelines/README.md`).
2. Follow [docs/implementation/README.md](docs/implementation/README.md) starting at **Phase 0** (branch protection) and **Phase 1** (Terraform).
3. Wire **Argo CD** using `gitops/bootstrap/root-app.yaml.example` and connect **service connections** (Workload Identity Federation) per the architecture doc.
