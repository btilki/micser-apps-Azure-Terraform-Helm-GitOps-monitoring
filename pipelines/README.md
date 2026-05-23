# Azure DevOps pipelines

| Path | Purpose |
|------|---------|
| `ci/` | One YAML pipeline per microservice (or shared entry with parameters) |
| `promote/` | `promote-to-stage`, `promote-to-prod` — `service` + optional `digest`; `az acr import` + GitOps PR + **HTTP smoke** (`scripts/smoke.sh`) when `smokeBaseUrl` is set |
| `templates/` | Reusable steps: build Go/.NET/Node, push ACR, Trivy, import image |

## Setup

Register **one pipeline per YAML** under `ci/` and `promote/` (`trigger: none` on CI by default — run manually). Service connections, variable groups, and fork setup: [DEPLOYMENT.md](../DEPLOYMENT.md). First CI pipeline walkthrough: [Phase 3 §2](../docs/implementation/phase-03-first-service-frontend.md#2-register-ci-in-azure-devops).

## Azure DevOps pipeline source after a GitHub rename

Each YAML pipeline stores which **GitHub repository** it checks out for `checkout: self` — Azure DevOps documentation and UI sometimes call this the **control repository** or **get sources** location. **Renaming the repo on GitHub does not automatically retarget existing pipelines.**

Do the following for **every** registered pipeline (`pipelines/ci/*.yml`, `pipelines/promote/*.yml`, optional root `azure-pipelines.yml`):

1. **GitHub — Azure Pipelines app access**  
   On GitHub: **Settings** → **Integrations** (or **Applications** under org/user) → **Installed GitHub Apps** → **Azure Pipelines**.  
   Under **Repository access**, ensure the renamed repository is included (or use “All repositories” while testing). Grant access if GitHub treats the rename as needing re-authorization.

2. **Azure DevOps — retarget the pipeline**  
   **Pipelines** → select the pipeline → **Edit**.  
   At the top of the YAML editor, confirm **Repository** and **Branch** (`main`) match the new GitHub repo (`btilki/micser-apps-Azure-Terraform-Helm-GitOps-monitoring` or your fork).  
   If the header still shows the old repository: use **⋮** (next to the pipeline name) → **Settings** / **Triggers** (wording varies by UI version) and change the **GitHub connection** + **repository** selection, or **Disconnect** the old repo link and **Choose repository** again from the GitHub picker.

3. **Save** the pipeline definition and run **Run pipeline** once to confirm checkout and variable groups still resolve.

4. **Branch protection (GitHub)** — If **required status checks** list Azure Pipelines by job name, confirm new runs from the retargeted pipelines still report the same check names; update the branch rule if job or pipeline names changed.

If you use **only Azure Repos** (not GitHub) as the pipeline source, mirror this repo into Azure Repos instead and point pipelines at that mirror; the same “each pipeline has one control repository” idea applies.

Promotion RBAC pre-check and role matrix: [DEPLOYMENT.md — Promotion SP roles](../DEPLOYMENT.md#promotion-service-principal-roles). Operational steps: [Phase 4](../docs/implementation/phase-04-promotion-pipeline.md).
