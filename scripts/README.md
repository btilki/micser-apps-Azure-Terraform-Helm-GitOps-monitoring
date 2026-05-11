# Scripts

Optional automation: local smoke tests, `az acr import` wrappers, codegen, or cluster helpers. Keep secrets out of scripts; use Azure DevOps secret variables or Key Vault in CI.

## `smoke.sh` (Phase 9)

HTTP checks for storefront URLs (curl, retries, expects **200**).

```bash
chmod +x scripts/smoke.sh   # once, after clone
./scripts/smoke.sh --env prod
./scripts/smoke.sh --url https://your-stage-host/
```

Override defaults with `SMOKE_DEV_URL`, `SMOKE_STAGE_URL`, `SMOKE_PROD_URL`, or `SMOKE_URLS` (space-separated). Used by **promote-to-stage** / **promote-to-prod** when `smokeBaseUrl` is set in `pipelines/templates/promote-image.yml`.

See [docs/runbooks/release-verification.md](../docs/runbooks/release-verification.md).
