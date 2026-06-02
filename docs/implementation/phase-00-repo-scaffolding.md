# Phase 0 — Repo scaffolding

[← Deployment](../../DEPLOYMENT.md) · [Phase 1 →](phase-01-terraform-foundation.md)

**Goal:** Prepare GitHub/Azure DevOps governance before infrastructure or deployments.

## Why this phase matters

Branch protection and **CODEOWNERS** enforce the same rules the rest of the platform assumes: infrastructure and prod GitOps change only through reviewed PRs. Azure DevOps pipelines need read access to the repo (and permission to open PR branches when CI updates digests).

If you **cloned this repository** with history intact, skip “initialize empty remote” and start at **step 4** (placeholders) after adding your `origin`.

## Process (brief)

Create or connect the remote repo, configure branch protection and owners, then verify that changes must go through PR review.

## Step-by-step

1. Decide source control platform:
   - Option A: GitHub (recommended if you use GitHub PR workflows in later phases).
   - Option B: Azure Repos (use equivalent policies in Azure DevOps).
2. Create remote repository:
   - initialize as empty (no README/license/gitignore)
   - set visibility and repository name
   - copy remote URL (`https` or `ssh`)
3. Connect local repo and push `main`:
   ```bash
   git remote add origin <REMOTE_URL>
   git push -u origin main
   ```
4. Replace template placeholders for your GitHub org, repository slug, and review teams — see [DEPLOYMENT.md — Fork setup](../../DEPLOYMENT.md#fork-setup-replace-placeholders) (GitOps `repoURL`, Azure Pipelines variables, `CODEOWNERS`).
5. Configure branch protection for `main` in GitHub:
   - `Settings -> Branches -> Add branch protection rule`
   - enable: PR required, required approvals, dismiss stale approvals
   - enable: require review from code owners
   - enable: require conversation resolution
   - disable: force pushes and branch deletion
6. If using Azure Repos as source control, configure equivalent branch policies:
   - `Project settings -> Repos -> Branches -> main -> Policies`
   - minimum reviewers, comment resolution, optional build validation
7. Add stricter ownership/path controls for:
   - `gitops/envs/prod/**`
   - `gitops/apps/prod/**`
8. Azure DevOps alignment (if pipelines are in Azure DevOps):
   - ensure pipeline identity has read access to the repository
   - ensure pipeline identity can create PR branches (if CI auto-opens GitOps PRs)
9. Validate governance with a small test PR:
   - direct push to `main` should fail
   - required reviewers/checks should appear

## Done checklist

- `main` exists on remote and is protected.
- `CODEOWNERS` is valid.
- Production GitOps paths require stricter review.

---

[← Deployment](../../DEPLOYMENT.md) · [Phase 1 →](phase-01-terraform-foundation.md)
