# Release verification checklist

Use after **image promotion** (Azure DevOps → GitOps PR) or any change you want to validate before calling a release “done”. Pair with [Phase 9 — Polish](../implementation/phase-09-polish.md).

## Before merge (GitOps PR)

- [ ] PR only touches the expected `gitops/envs/<env>/values-<service>.yaml` (and no unrelated secrets).
- [ ] `image.digest` is `sha256:` + 64 hex characters; `repository` matches the target ACR for that environment.
- [ ] CI for that service passed on the digest you are promoting (Trivy, build).

## After merge (Argo CD)

- [ ] `kubectl get applications -n argocd` — child app for the service is **Synced** / **Healthy** (or briefly **Progressing** then healthy).
- [ ] `kubectl get pods -n <dev|stage|prod>` — new pods **Ready**; no sustained **CrashLoopBackOff**.
- [ ] `kubectl rollout status deploy/<release>-<chart> -n <ns> --timeout=120s` for the touched workload.

## Smoke (HTTP)

From your machine or CI:

```bash
./scripts/smoke.sh --env stage   # or dev / prod
```

Or override hosts for your fork:

```bash
export SMOKE_STAGE_URL="https://stage.example.com"
./scripts/smoke.sh --url "$SMOKE_STAGE_URL"
```

Expect **HTTP 200** on the storefront URL. Promotion pipelines also run this check when `smokeBaseUrl` is set in `pipelines/templates/promote-image.yml` (see `promote-to-stage.yml` / `promote-to-prod.yml`).

**Note:** Smoke immediately after promotion may still hit the **previous** revision until Argo applies the merged PR; re-run smoke after sync if needed.

## Observability

- [ ] Grafana: workload and ingress panels look normal (see [grafana-dashboards](./grafana-dashboards.md)).
- [ ] No unexpected firing alerts in Alertmanager / notification channel after the change window.

## Rollback

If verification fails after merge, follow [prod-rollback](./prod-rollback.md) (or revert the PR and re-sync).
