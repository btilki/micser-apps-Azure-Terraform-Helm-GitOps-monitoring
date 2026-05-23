# Runbooks

Operational procedures for **boutique** prod and shared platform. Index: [TROUBLESHOOTING.md](../../TROUBLESHOOTING.md). Pair with [Phase 7](../implementation/phase-07-prod-environment.md).

| Runbook | Use when |
|---------|----------|
| [release-verification](./release-verification.md) | After a promotion PR merge; smoke + Argo + quick observability checks |
| [grafana-dashboards](./grafana-dashboards.md) | Release monitoring; find capacity / ingress / pod / cert dashboards |
| [prod-rollback](./prod-rollback.md) | Bad deploy in prod; revert GitOps digest/values and Sync |
| [ingress-5xx-triage](./ingress-5xx-triage.md) | HTTP 5xx via ingress; LB/backend/controller issues |
| [certificate-renewal-expiry](./certificate-renewal-expiry.md) | TLS errors; cert-manager / ACME / expiry |
| [failing-argocd-sync-prod](./failing-argocd-sync-prod.md) | Argo prod app won’t sync or stays unhealthy |

**Escalation:** See [prod branch protection — approver teams](../gitops/prod-branch-protection.md) (`prod-gitops-approvers`, `prod-gitops-secondary`). Replace with your on-call roster in your internal wiki if different.
