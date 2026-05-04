# Phase 5 — Fan-out remaining services

[← Phase 4](phase-04-promotion-pipeline.md) · [Index](README.md) · [Phase 6 →](phase-06-stage-environment.md)

**Goal:** All boutique services (+ Redis) running in **dev**; only `frontend` has Ingress.

---

## Implementation

> **Use:** Copy-paste from `frontend` pattern: editor, **Helm**, **Azure DevOps** (clone pipeline per service or parameterized template), **Argo CD** (many Applications), terminal for quick checks.

1. **Service list** — `cartservice`, `productcatalogservice`, `currencyservice`, `paymentservice`, `shippingservice`, `emailservice`, `checkoutservice`, `recommendationservice`, `adservice`, `redis-cart`, `loadgenerator` (disable in prod later via values).

2. **Per service:** `charts/<name>/`, `gitops/apps/dev/<name>.yaml`, `gitops/envs/dev/values-<name>.yaml`, `pipelines/ci/<name>.yaml` (or shared template with matrix).

3. **Build templates** — Reuse `pipelines/templates/` for Go, .NET, Node, Python, Java as needed.

4. **Argo CD** — Register each child Application under `gitops/bootstrap/applications/`.

5. **Smoke** — `kubectl get pods -n dev`; port-forward or internal curl between services if something fails.

---

## Checklist

- [ ] All dev workloads Running / Ready.
- [ ] Frontend still reachable; internal calls (checkout, cart, etc.) work end-to-end.

---

## Your notes / extra steps

-
