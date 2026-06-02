# Production GitOps: branch protection and approvers

This repo uses strict controls for anything under **`gitops/envs/prod/`** and **`gitops/apps/prod/`**. Automation and humans must go through reviewed pull requests to `main`.

## Approver groups (GitHub teams)

Define these teams in your GitHub **organization** (or ensure equivalent groups exist) and grant them **write** access to the repository if they should approve merges.

| Team slug (example) | Role |
|---------------------|------|
| **`prod-gitops-approvers`** | Primary owners for prod GitOps paths (`CODEOWNERS`). Responsible for image digests, Argo `Application` definitions, and prod values. |
| **`prod-gitops-secondary`** | Second line of review; use for four-eyes / cab-style approval alongside the primary team. |

**Organization in this project:** `YOUR_ORG` (replace in `CODEOWNERS` and team mentions if your org differs).

**CODEOWNERS** lists both teams on prod paths so both are notified; **two distinct approvals** are enforced by the **`main`** branch protection rule below (minimum **2** approving reviews), not by CODEOWNERS alone.

## `main` branch protection (GitHub UI)

In the repository: **Settings → Branches → Branch protection rule** for `main` (or use **Rulesets** with equivalent options).

Enable at least:

1. **Require a pull request before merging**  
   - **Required number of approvals before merging:** `2`  
   - **Dismiss stale pull request approvals when new commits are pushed:** recommended on  
   - **Require review from Code Owners:** on (pairs with root `CODEOWNERS` for prod paths)

2. **Require status checks to pass before merging**  
   - Add the checks your Azure DevOps (or GitHub Actions) pipelines report on PRs, e.g. build/validate jobs.  
   - **Require branches to be up to date before merging:** recommended on

3. **Require conversation resolution before merging**  
   - Ensures all review comments are marked resolved before merge.

4. **Block direct pushes** to `main`  
   - Do **not** allow bypass for admins if you want the same rules for everyone, or document who may bypass and when.

5. **Restrict who can push** (optional but strict)  
   - Limit merge/push to specific teams (e.g. `prod-gitops-approvers` + release managers).

Path-specific “only these folders need 2 reviews” is not modeled separately in classic branch rules: the **2 approvals** apply to any PR targeting `main`. Combine with **CODEOWNERS** so prod changes always pull in the right owners. For PRs that only touch non-prod paths, you still need 2 approvals if that is your global rule—adjust team process or use [rulesets](https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/managing-rulesets/about-rulesets) if you need finer granularity.

## Verify

- Open a test PR touching only `gitops/envs/prod/README` (or a trivial comment): confirm 2 approvals are required and CODEOWNERS requests the prod teams.
- Confirm you cannot push to `main` with `git push origin main` from a normal developer account.

## Related files

- Root **`CODEOWNERS`** — prod path → `@YOUR_ORG/prod-gitops-approvers` and `@YOUR_ORG/prod-gitops-secondary`
- [Phase 7 — Prod environment](../implementation/phase-07-prod-environment.md)
