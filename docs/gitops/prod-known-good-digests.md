# Production — known-good image digests (rollback reference)

**Manual checklist.** Update this file **after each successful prod release** (or paste into your incident/wiki instead). GitOps **`gitops/envs/prod/*.yaml`** remains the live source of truth; this table is for **fast rollback** when you need the **last good** `sha256` without spelunking history.

| Service | Last known-good digest | Updated (UTC) | Release / PR / note |
|---------|------------------------|---------------|-------------------|
| frontend | `sha256:…` | | |
| redis-cart | `sha256:…` | | |
| cartservice | `sha256:…` | | |
| currencyservice | `sha256:…` | | |
| productcatalogservice | `sha256:…` | | |

**How to find digests when updating:**

```bash
grep -h '^  digest:' gitops/envs/prod/values-*.yaml
```

Or from Git history:

```bash
git log -1 -p -- gitops/envs/prod/values-frontend.yaml
```

**Rollback:** paste the saved digest into `gitops/envs/prod/values-<service>.yaml`, open PR, merge, **manual Argo Sync** — see [prod rollback runbook](../runbooks/prod-rollback.md).
