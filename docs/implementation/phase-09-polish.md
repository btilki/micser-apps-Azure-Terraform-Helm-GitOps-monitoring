# Phase 9 — Polish

[← Phase 8](phase-08-hardening.md) · [Index](README.md)

**Goal:** Dashboards, automated smoke test, README demo path.

---

## Implementation

> **Use:** **Grafana** UI (import JSON dashboards), **Azure DevOps** (smoke step in pipeline) or **scripts/** with `curl`, editor for **README**, optional screen recording.

1. **Grafana** — Import or build dashboards: cluster capacity, ingress latency/errors, key service metrics, cert expiry.

2. **Smoke test** — Script or pipeline step: `curl -sf https://<prod-or-stage-host>/` and any critical API checks; fail pipeline on non-200.

3. **README** — Short “happy path”: commit → CI → dev → promote → stage → promote → prod → manual sync.

4. **Optional** — Demo recording or screenshots for handover.

---

## Checklist

- [ ] Someone new can follow README for the full flow.
- [ ] Smoke step passes on a known-good deployment.

---

## Your notes / extra steps

-
