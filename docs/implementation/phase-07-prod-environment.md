# Phase 7 — Prod environment

[← Phase 6](phase-06-stage-environment.md) · [Index](README.md) · [Phase 8 →](phase-08-hardening.md)

**Goal:** Prod GitOps, **manual** Argo CD sync for prod, alerts, short runbooks.

---

## Implementation

> **Use:** **Argo CD** (projects, sync policy manual, RBAC), **Git** (strict PR rules for `gitops/envs/prod/**`), **Helm values**, **Alertmanager** config (YAML + reload), **Grafana** UI optional, `docs/runbooks/`.

1. **GitOps** — `gitops/apps/prod/*`, `gitops/envs/prod/*`: prod ACR, turn off `loadgenerator`, higher replicas/PDBs.

2. **Argo CD** — **AppProject** `boutique-prod`: disable auto-sync; restrict who can **Sync** (Argo CD **RBAC** / SSO groups).

3. **Alertmanager** — In Prometheus stack values: set **receiver** (email, Slack webhook, etc.); apply; send test alert.

4. **Runbooks** — Add `docs/runbooks/` entries: rollback = revert GitOps PR + sync; cert expiry; ingress 5xx.

5. **Promote-to-prod** — Run pipeline with approvals; merge prod GitOps PR; **operator clicks Sync** in Argo CD for prod.

---

## Checklist

- [ ] Prod URL + TLS correct.
- [ ] Prod does not auto-sync without human action.
- [ ] Test notification reaches your channel.

---

## Your notes / extra steps

-
