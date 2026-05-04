# Phase 4 — Promotion pipeline

[← Phase 3](phase-03-first-service-frontend.md) · [Index](README.md) · [Phase 5 →](phase-05-fan-out-services.md)

**Goal:** One-click (or manual) **dev → stage** and **stage → prod** image copy via `az acr import` + GitOps PRs with the same digest.

---

## Implementation

> **Use:** **Azure DevOps** (new pipelines, **Environments**, **approvals**, **service connections**), terminal (`az acr import` in scripts), **Git** (PRs to `gitops/envs/stage` and `prod`), **Azure Portal** (ACR IAM if debugging).

1. **Service connection** — Identity that can read source ACR and write/import to target ACR (federated credential or secret-based SP). Test from a manual pipeline: `az login` / `az acr import --help` flow.

2. **`pipelines/promote/promote-to-stage.yml`** — Parameters or script: read digest from `gitops/envs/dev/` (or variables). Steps: `az acr import` from dev registry to stage registry; clone repo; branch; patch `gitops/envs/stage/*.yaml` (registry + digest); push branch; create PR (Azure DevOps **Create Pull Request** task or REST).

3. **`pipelines/promote/promote-to-prod.yml`** — Same for stage → prod and `gitops/envs/prod/`. Add **manual validation** / **environment approval** on prod.

4. **Branch policies** — On `main`, require reviewers for `gitops/envs/prod/**` (Azure DevOps **Path filters** in policy).

5. **Run** — Execute promote-to-stage manually; merge PR; confirm Argo CD updates stage. Repeat pattern for prod.

---

## Checklist

- [ ] Same `sha256` digest visible in target ACR (Portal or `az acr repository show-manifests`).
- [ ] GitOps files for stage/prod reference the correct registry + digest.

---

## Your notes / extra steps

-
