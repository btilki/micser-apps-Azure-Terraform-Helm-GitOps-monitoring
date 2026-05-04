# Phase 0 — Repo scaffolding

[← Index](README.md) · [Phase 1 →](phase-01-terraform-foundation.md)

**Goal:** Remote Git repo configured; branch rules and ownership set.

---

## Implementation

> **Use:** Git (terminal), GitHub or **Azure DevOps** (Repos → **Branches** / **Policies**), editor for `CODEOWNERS`.

1. **Push this repo** to your Git host (new empty repo, then `git remote add origin …`, `git push -u origin main`).
2. **Edit `CODEOWNERS`** at repo root — replace placeholder handles with real users or teams.
3. **Protect `main`**
   - *GitHub:* Repo → **Settings** → **Branches** → Add rule for `main` (require PR, reviewers, optional status checks).
   - *Azure DevOps:* **Project settings** → **Repositories** → your repo → **Policies** → branch `main` (minimum reviewers; add build policy when pipelines exist).
4. **Optional:** Extra policy for path `gitops/envs/prod/**` (more reviewers).

---

## Checklist

- [ ] `CODEOWNERS` matches real reviewers.
- [ ] Direct push to `main` is blocked the way you want.

---

## Your notes / extra steps

-
