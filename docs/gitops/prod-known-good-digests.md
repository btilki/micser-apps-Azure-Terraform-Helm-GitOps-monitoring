# Production — known-good image digests (rollback reference)

**Manual checklist.** Update this file **after each successful prod release** (or paste into your incident/wiki instead). GitOps **`gitops/envs/prod/*.yaml`** remains the live source of truth; this table is for **fast rollback** when you need the **last good** `sha256` without spelunking history.

| Service | Last known-good digest | Updated (UTC) | Release / PR / note |
|---------|------------------------|---------------|-------------------|
| frontend | `sha256:a7ea6e5a8b398ef9070e29735ed546ca85f261846bc9101d90ce97f760791933` | 2026-05-11 | Synced from `gitops/envs/prod/values-frontend.yaml` on branch — update after each prod ship |
| redis-cart | `sha256:f337cad04ce49504acde20d4286a29e28d595b7fa61d16c0afac0a5190e4ebd1` | 2026-05-11 | |
| cartservice | `sha256:00826f3b030c1ffab3c8146ecba31b35dbda04fc29a619e60f7d68658cc8e073` | 2026-05-11 | |
| currencyservice | `sha256:bdbed665caa2b1afe72d01e2d5885587d543b2aaeb5587538d81921e7a777251` | 2026-05-11 | |
| productcatalogservice | `sha256:1678d5f0b049b8c1f099e597ce635c2bae416fa3611cdd9faac8459ce2ba94a9` | 2026-05-11 | |

**How to find digests when updating:**

```bash
grep -h '^  digest:' gitops/envs/prod/values-*.yaml
```

Or from Git history:

```bash
git log -1 -p -- gitops/envs/prod/values-frontend.yaml
```

**Rollback:** paste the saved digest into `gitops/envs/prod/values-<service>.yaml`, open PR, merge, **manual Argo Sync** — see [prod rollback runbook](../runbooks/prod-rollback.md).
