# Runbook: Production rollback (GitOps)

## Symptoms

- Users report broken UI/API after a prod deploy or Git merge.
- Error rate or latency spikes on `boutique.biroltilki.art` / `api.boutique.biroltilki.art`.
- Argo CD shows prod app **Synced** but workloads misbehave after a **digest** or **values** change.
- Azure Monitor / Alertmanager fires **BoutiqueHighHttp5xxRatio** or customer-visible SLO breach.

## Immediate checks

1. **Scope:** Which service(s)? Note time of last **merge to `main`** touching `gitops/envs/prod/` or last **manual Sync** in Argo CD.
2. **Cluster:**
   ```bash
   kubectl get pods -n prod
   kubectl get events -n prod --sort-by='.lastTimestamp' | tail -30
   ```
3. **Image:** Compare current `image.digest` in `gitops/envs/prod/values-<service>.yaml` on `main` with last known good (previous commit or stage values).
4. **Argo:** In UI or CLI: app **sync status**, **health**, and **last sync** revision.

## Rollback / mitigation

1. **Preferred — Git revert / pin digest**
   - Open a PR that restores the previous **`image.digest`** (and any bad values) in `gitops/envs/prod/values-<service>.yaml`, or **revert** the offending commit on `main` (follow [prod branch protection](../gitops/prod-branch-protection.md): two reviewers).
2. **Merge** the fix PR.
3. **Argo CD:** **Sync** the affected prod `Application`(s) manually (`*-prod` apps use manual sync).
4. **Verify:**
   ```bash
   kubectl rollout status deployment/<release>-<chart> -n prod
   curl -sS -o /dev/null -w "%{http_code}" https://boutique.biroltilki.art/
   ```
5. **If only runtime config is wrong** (not image): fix values in Git, merge, Sync again — avoid `kubectl set image` unless emergency; Git must remain source of truth.

## Owner / escalation

| Tier | Who | When |
|------|-----|------|
| **L1** | On-call engineer | Triage, execute rollback PR + Argo Sync |
| **L2** | `prod-gitops-approvers` (GitHub team) | Approve prod GitOps PRs, confirm digest/ACR correctness |
| **L3** | Platform / AKS owner | Node/CNI/registry outages blocking rollout |

Escalate if rollback PR cannot merge (policy), Sync fails repeatedly, or pods stay **CrashLoop** after correct digest.
