# Azure DevOps pipelines

| Path | Purpose |
|------|---------|
| `ci/` | One YAML pipeline per microservice (or shared entry with parameters) |
| `promote/` | `promote-to-stage`, `promote-to-prod` (`az acr import` + GitOps PR) |
| `templates/` | Reusable steps: build Go/.NET/Node, push ACR, Trivy, import image |

## Connect this repo in Azure DevOps

1. Create a **Project** and import or connect this repository (**Azure Repos** or **GitHub** service connection).
2. Create **Environments** / **Service connections** (ARM, ACR, Workload Identity Federation per architecture §8–9).
3. Create pipelines from existing YAML: **Pipelines → New pipeline → Existing Azure Pipelines YAML file** and pick `azure-pipelines.yml` or a file under `ci/`.
4. Replace placeholders in variable groups (subscription ID, ACR names, GitOps repo URL) before first run.

See `docs/cicd-pipeline-plan.md` and `docs/implementation/phase-03-first-service-frontend.md`.
