# Phase 8 — Hardening

[← Phase 7](phase-07-prod-environment.md) · [Index](README.md) · [Phase 9 →](phase-09-polish.md)

**Goal:** NetworkPolicies, PSS, quotas, CI image gate, cost alert.

---

## Implementation

> **Use:** Editor + `kubectl apply`, **Helm** (chart hooks optional), **Azure DevOps** (fail Trivy on HIGH/CRITICAL), **Azure Portal** → **Cost Management** → **Budgets**.

1. **NetworkPolicies** — Add YAML under `policies/` (or embed in charts); apply per namespace; default deny then allow lists between required services.

2. **Pod Security** — Label namespaces: `pod-security.kubernetes.io/enforce` = `baseline` (dev), `restricted` (stage/prod). Fix workloads that fail admission.

3. **Quotas** — `ResourceQuota` + `LimitRange` per env namespace (`kubectl` or GitOps).

4. **Trivy** — In CI templates, set exit code on HIGH/CRITICAL; run a known-bad image to verify pipeline fails.

5. **Budget** — Portal: create **Budget** on subscription or RG scope; **alert** at 80% (email/action group).

---

## Checklist

- [ ] Unwanted cross-namespace traffic blocked (spot-check with `kubectl run` / curl).
- [ ] Unsafe pod specs rejected in stage/prod.
- [ ] Azure budget alert fires in a test (or configuration verified).

---

## Your notes / extra steps

-
