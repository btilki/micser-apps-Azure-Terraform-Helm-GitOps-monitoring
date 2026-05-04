# Phase 6 — Stage environment

[← Phase 5](phase-05-fan-out-services.md) · [Index](README.md) · [Phase 7 →](phase-07-prod-environment.md)

**Goal:** Stage namespace(s) + Argo CD project + GitOps for **stage** ACR; URL works after promotion.

---

## Implementation

> **Use:** Editor, **Git/PRs**, **Argo CD** (Projects, Applications, sync), **Helm values**, **Phase 4** promote pipeline to fill stage ACR.

1. **GitOps** — Add `gitops/apps/stage/*.yaml` and `gitops/envs/stage/*.yaml` (stage ACR login server, digests from promotion, replicas/resources for stage).

2. **Argo CD** — Create **AppProject** `boutique-stage` (allowed repos, namespaces, cluster). Point stage Applications at `project: boutique-stage`.

3. **Scheduling** — Values: `nodeSelector` / `tolerations` for `env=stage` (match AKS node pool taints).

4. **Docs** — Short note in repo or wiki: who approves promote PRs, link to pipeline.

5. **Run promote-to-stage** — Merge GitOps PRs; **Sync** in Argo CD if needed.

---

## Checklist

- [ ] `https://stage.<your-domain>/` (or configured host) works after sync.
- [ ] Images pull from **stage** ACR only for stage apps.

---

## Your notes / extra steps

-
