# Phase 4 — Promotion pipeline

[← Phase 3](phase-03-first-service-frontend.md) · [Index](README.md) · [Phase 5 →](phase-05-fan-out-services.md)

**Goal:** Promote images by digest across environments without rebuilding.

## Process (brief)

Use one reusable promotion template and environment-specific wrappers. Each run imports a tested digest to target ACR, updates GitOps values, and opens a PR.

## Step-by-step

1. In Azure, verify promotion identity permissions:
   - source ACR: `AcrPull`
   - target ACR: `AcrPush`
   Check with:
   ```bash
   az role assignment list --assignee <PRINCIPAL_ID_OR_APP_ID> -o table
   ```
2. In Azure DevOps, verify service connections and variable groups:
   - service connection can access source/target ACR
   - GitHub token/connection is available for PR creation
   - required variables are set (`SOURCE_ACR`, `TARGET_ACR`, service name, branch)
3. Use `pipelines/templates/promote-image.yml` as the single shared promotion logic.
4. Use wrapper pipelines:
   - `pipelines/promote/promote-to-stage.yml`
   - `pipelines/promote/promote-to-prod.yml`
5. In Azure DevOps, configure environment approvals/checks:
   - `promote-stage` environment checks
   - `promote-prod` environment checks (required)
6. Run stage promotion pipeline manually and review generated GitHub PR:
   - confirm only `gitops/envs/stage/values-*.yaml` changed
   - confirm digest format is `sha256:<64-hex>`
   - merge after review
7. Verify stage ACR import and deployment:
   ```bash
   az acr manifest list-metadata --registry <STAGE_ACR_NAME> --name <SERVICE> -o table
   kubectl get applications -n argocd
   ```
8. Run prod promotion pipeline, complete approval gate, and review GitHub PR with stricter checks:
   - verify target repository is prod ACR
   - verify digest matches tested stage digest
   - merge only after required reviewers approve
9. Sync and verify prod:
   ```bash
   kubectl get applications -n argocd
   kubectl get pods -n prod
   ```
10. Confirm digest parity in GitOps values across environments for the promoted service.

## Detailed step-by-step guide (practical)

Use this sequence for one service (example: `frontend`) and repeat for each owned service.

### 0) Prerequisites

1. Confirm access:
   ```bash
   az account show -o table
   kubectl get nodes
   kubectl get applications -n argocd
   ```
2. Confirm expected ACR names exist:
   ```bash
   az acr list -o table
   ```
   For this repository convention:
   - dev: `acrboutiquedevweu`
   - stage: `acrboutiquestageweu`
   - prod: `acrboutiqueprodweu`

### 1) Validate promotion identity permissions in Azure

1. Resolve principal ID used by Azure DevOps promotion service connection:
   ```bash
   az ad sp list --display-name "promotion-azure-connection" --query "[0].id" -o tsv
   ```
   If your display name differs, use your real service principal/app registration.
2. Verify role assignments:
   ```bash
   az role assignment list --assignee <PRINCIPAL_ID_OR_APP_ID> -o table
   ```
3. Minimum expected access:
   - dev -> stage promotion:
     - source dev ACR: `AcrPull`
     - target stage ACR: `AcrPush`
   - stage -> prod promotion:
     - source stage ACR: `AcrPull`
     - target prod ACR: `AcrPush`

### 2) Validate Azure DevOps pipeline dependencies

1. Check service connection:
   - Azure DevOps -> Project settings -> Service connections
   - ensure `promotion-azure-connection` is authorized for promotion pipelines.
2. Check variable group:
   - Azure DevOps -> Pipelines -> Library
   - ensure `variable-group-for-microservices` contains required values and secret `GITHUB_TOKEN`.
3. Check environments:
   - Azure DevOps -> Pipelines -> Environments
   - ensure `promote-stage` and `promote-prod` exist.
   - add approval checks on `promote-prod`.

### 3) Review pipeline YAML layout in repo

1. Shared promotion logic:
   - `pipelines/templates/promote-image.yml`
2. Wrapper pipelines:
   - `pipelines/promote/promote-to-stage.yml`
   - `pipelines/promote/promote-to-prod.yml`
3. Ensure wrappers pass required parameters:
   - service name
   - source registry
   - target registry
   - GitOps values path for target environment

### 4) Run stage promotion and verify PR

1. Queue `pipelines/promote/promote-to-stage.yml` manually in Azure DevOps.
2. After success, open created GitHub PR and verify:
   - only `gitops/envs/stage/values-<service>.yaml` changed
   - image points to stage ACR
   - digest format is `sha256:<64-hex>`
3. Merge PR after review.

### 5) Verify stage import and rollout

1. Verify image exists in stage ACR:
   ```bash
   az acr manifest list-metadata --registry acrboutiquestageweu --name frontend -o table
   ```
2. Verify Argo status:
   ```bash
   kubectl get applications -n argocd
   kubectl get pods -n stage
   ```
3. Verify deployed image digest:
   ```bash
   kubectl get pod -n stage -o jsonpath='{range .items[*]}{.metadata.name}{" => "}{.spec.containers[*].image}{"\n"}{end}'
   ```

### 6) Run prod promotion with approval gate

1. Queue `pipelines/promote/promote-to-prod.yml`.
2. Complete required Azure DevOps environment approval (`promote-prod`).
3. Review generated GitHub PR:
   - only `gitops/envs/prod/values-<service>.yaml` changed
   - repository points to prod ACR
   - digest matches previously validated stage digest
4. Merge PR only after required reviewers approve.

### 7) Verify prod rollout and parity

1. Verify image exists in prod ACR:
   ```bash
   az acr manifest list-metadata --registry acrboutiqueprodweu --name frontend -o table
   ```
2. Verify cluster rollout:
   ```bash
   kubectl get applications -n argocd
   kubectl get pods -n prod
   ```
3. Confirm digest parity in GitOps:
   - compare digests between `gitops/envs/stage/values-<service>.yaml` and `gitops/envs/prod/values-<service>.yaml`
   - prod digest should equal approved stage digest for same release

### 8) Troubleshooting quick map

- PR not created:
  - validate `GITHUB_TOKEN` permissions and pipeline variable references.
- `az acr import` fails:
  - validate source `AcrPull` and target `AcrPush` role assignments.
- Wrong file modified in PR:
  - validate wrapper pipeline parameters and values file path.
- Argo app out of sync after merge:
  - verify app references correct values file and branch.
- Digest mismatch between stage/prod:
  - rerun promotion using exact stage digest parameter and re-review PR.

## Done checklist

- Promotions run via pipeline and produce GitOps PRs.
- Stage and prod use imported digests (not rebuilt images).
- Promotion to prod is approval-gated.
