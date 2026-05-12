# Azure DevOps pipelines

| Path | Purpose |
|------|---------|
| `ci/` | One YAML pipeline per microservice (or shared entry with parameters) |
| `promote/` | `promote-to-stage`, `promote-to-prod` — `service` + optional `digest`; `az acr import` + GitOps PR + **HTTP smoke** (`scripts/smoke.sh`) when `smokeBaseUrl` is set |
| `templates/` | Reusable steps: build Go/.NET/Node, push ACR, Trivy, import image |

## Connect this repo in Azure DevOps

1. Create a **Project** and import or connect this repository (**Azure Repos** or **GitHub** service connection).
2. Create **Environments** / **Service connections**.
   - Required now:
     - `promotion-azure-connection` (Azure Resource Manager; used by promotion and CI AzureCLI steps)
   - Optional:
     - A dedicated dev ARM connection (if you later split CI/prod identities)
     - A dedicated ACR Docker connection (not required with current CI AzureCLI flow)
3. Create pipelines from existing YAML: **Pipelines → New pipeline → Existing Azure Pipelines YAML file**. Register **one pipeline per file** under `ci/` and `promote/`. **Service CI** files under `ci/` use `trigger: none` / `pr: none` so GitHub pushes do not start builds automatically — use **Run pipeline** in Azure DevOps (or restore branch/path triggers in YAML when you want CI on every commit). Promote wrappers are already manual-only. Optionally register root `azure-pipelines.yml` as a manual layout check.
4. Configure variable groups before first run.
   - Required now:
     - `variable-group-for-microservices`
     - secret variable: `GITHUB_TOKEN`

See the repository [README.md](../README.md) (system overview) and [docs/implementation/phase-03-first-service-frontend.md](../docs/implementation/phase-03-first-service-frontend.md).

## Promotion permissions control

Promotion pipelines enforce a pre-check (`pipelines/templates/promote-image.yml`) on the service principal used by **`promotion-azure-connection`** before `az acr import` and the GitHub PR step.

| Pipeline | Source registry / roles | Target registry / roles | Reader (resource groups) |
|----------|---------------------------|-------------------------|---------------------------|
| `promote/promote-to-stage.yml` | `acrboutiquedevweu` — **AcrPull** | `acrboutiquestageweu` — **AcrPull**, **AcrPush** | `rg-boutique-stage-weu`, `rg-boutique-prod-weu` |
| `promote/promote-to-prod.yml` | `acrboutiquestageweu` — **AcrPull** | `acrboutiqueprodweu` — **AcrPush** | same as stage row |

To change scopes, edit `requiredSourceAcrRoles`, `requiredTargetAcrRoles`, and `requiredReaderResourceGroups` on each wrapper. Details: `docs/implementation/phase-04-promotion-pipeline.md`.

If the first Azure CLI step fails with **`Missing role 'AcrPull' on source ACR`**, grant that role to the **promotion** service principal on the dev registry (and the other roles in the table above on stage/prod ACRs and RGs). Terraform: set optional `promotion_service_principal_object_id` (**enterprise application** Object ID) in each env’s `terraform.tfvars` and apply `infra/terraform/envs/{dev,stage,prod}/`.
