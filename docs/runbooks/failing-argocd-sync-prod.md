# Runbook: Failing Argo CD sync (production)

## Symptoms

- Prod Argo `Application` **OutOfSync**, **Unknown**, **Degraded**, or **Sync failed** in UI.
- `kubectl get application -n argocd` shows **SyncError** / **Health Degraded** for `*-prod` or `platform-prod`.
- Git merge succeeded but cluster does not match desired state.

## Immediate checks

1. **Application message:**
   ```bash
   kubectl describe application frontend-prod -n argocd
   ```
   Read **Status.Conditions** and **Operation State** message (RBAC, invalid manifest, webhook, resource quota).
2. **Diff:** In Argo UI **App diff** or:
   ```bash
   argocd app diff frontend-prod
   ```
3. **Target revision:** Confirm `targetRevision: main` and repo **commit** is what you expect.
4. **Project:** `project: boutique-prod` — **AppProject** must allow destination **namespace `prod`** and resource kinds (e.g. **PDB**, **PriorityClass** for platform).
5. **Cluster capacity:** `kubectl describe pod -n prod` for **FailedScheduling** / **quota** exceeded.
6. **Admission / webhooks:** **502** from **nginx** validating webhook → see [ingress 5xx](./ingress-5xx-triage.md) / restart controller off bad node.

## Rollback / mitigation

| Cause | Mitigation |
|--------|------------|
| **Invalid YAML / Helm** | Fix chart or values in Git; merge; **Refresh** + **Sync**. |
| **Image pull / bad digest** | Correct `image.digest` in `gitops/envs/prod/`; confirm image in **prod ACR**; **AcrPull** for kubelet identity. |
| **AppProject denies resource** | Adjust `gitops/apps/prod/project-boutique-prod.yaml` **whitelist/blacklist**; apply carefully; re-Sync. |
| **Quota / PDB / scheduling** | Adjust **ResourceQuota** / replicas / node pool; see [prod-rollback](./prod-rollback.md). |
| **Stale cache** | `kubectl -n argocd annotate application boutique-root argocd.argoproj.io/refresh=hard --overwrite` then Sync child app. |

**Manual sync (prod policy):**
```bash
kubectl -n argocd patch application frontend-prod --type merge -p '{"operation":{"sync":{"prune":true}}}'
```

## Owner / escalation

| Tier | Who | When |
|------|-----|------|
| **L1** | On-call engineer | Read Argo conditions, diff, retry Sync |
| **L2** | `prod-gitops-approvers` | Git fixes, AppProject, Helm chart paths |
| **L3** | Platform | Argo CD / **repo-server** outages, cluster API, CRD conflicts |

Escalate if **multiple** apps fail with **ComparisonError** (repo or **helm** tool failure) or **controller** not reconciling.
