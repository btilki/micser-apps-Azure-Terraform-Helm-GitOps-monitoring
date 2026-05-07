# Azure DevOps pipelines

| Path | Purpose |
|------|---------|
| `ci/` | One YAML pipeline per microservice (or shared entry with parameters) |
| `promote/` | `promote-to-stage`, `promote-to-prod` (`az acr import` + GitOps PR) |
| `templates/` | Reusable steps: build Go/.NET/Node, push ACR, Trivy, import image |

## Connect this repo in Azure DevOps

1. Create a **Project** and import or connect this repository (**Azure Repos** or **GitHub** service connection).
2. Create **Environments** / **Service connections**.
   - Required now:
     - `promotion-azure-connection` (Azure Resource Manager; used by promotion and CI AzureCLI steps)
   - Optional:
     - A dedicated dev ARM connection (if you later split CI/prod identities)
     - A dedicated ACR Docker connection (not required with current CI AzureCLI flow)
3. Create pipelines from existing YAML: **Pipelines → New pipeline → Existing Azure Pipelines YAML file** and pick `azure-pipelines.yml` or a file under `ci/`.
4. Configure variable groups before first run.
   - Required now:
     - `variable-group-for-microservices`
     - secret variable: `GITHUB_TOKEN`

See `docs/cicd-pipeline-plan.md` and `docs/implementation/phase-03-first-service-frontend.md`.

## Promotion permissions control

Promotion pipelines now enforce a pre-check for required Azure RBAC roles on the promotion service principal before image import and GitOps PR creation.

For required role mappings (dev/stage/prod ACR + Reader scopes), see `README.md` section `Promotion SP role control`.
