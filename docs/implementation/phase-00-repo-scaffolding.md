# Phase 0 — Repo scaffolding

[← Index](README.md) · [Phase 1 →](phase-01-terraform-foundation.md)

**Goal:** Prepare GitHub/Azure DevOps governance before infrastructure or deployments.

## Process (brief)

Create the remote repo, configure branch protection and owners, then verify that changes must go through PR review.

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
4. Update `CODEOWNERS` in repo root with real teams/users.
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
- `CODEOWNERS` is valid for your team.
- Production GitOps paths require stricter review.
