# Phase 8 — Hardening

[← Phase 7](phase-07-prod-environment.md) · [Index](README.md) · [Phase 9 →](phase-09-polish.md)

**Goal:** Apply operational/security guardrails across runtime, CI, and cost.

## Process (brief)

Roll out hardening in `dev` first, then promote to `stage` and `prod`. Use explicit policies and validate each control before promoting to the next environment.

## Step-by-step

### Prerequisites

1. Ensure stage and prod are stable before applying stronger restrictions:
   ```bash
   kubectl get applications -n argocd
   kubectl get pods -n stage
   kubectl get pods -n prod
   ```

### GitHub / GitOps

2. Use policy manifests in repo (`policies/` and/or GitOps platform paths) for network isolation:
   - default deny
   - explicit allow paths needed by services
3. Roll out policy changes in PRs per environment order: `dev -> stage -> prod`.
4. Apply Pod Security labels:
   - `dev`: baseline
   - `stage`, `prod`: restricted
5. Add/update `ResourceQuota` and `LimitRange` in each environment namespace.

### Azure DevOps

6. In CI templates/pipelines, enforce Trivy gate for HIGH/CRITICAL findings.
7. Run pipeline validation on a test PR and confirm vulnerable images fail the quality gate.

### Azure

8. In Azure Portal, configure budget alerts (minimum 80% threshold) for subscription or resource groups.
9. Confirm notification routing for budget alerts (email/action group).

### Argo CD / Kubernetes validation

10. Validate each environment after policy rollout:
   ```bash
   kubectl get networkpolicy,resourcequota,limitrange -A
   kubectl get ns --show-labels
   ```
11. Validate traffic behavior for key paths (frontend -> cart/product/catalog flows).

### Troubleshooting

- Services break after NetworkPolicy rollout:
  - temporarily relax only the affected allow rules in `dev`, validate, then promote fix.
- Pods rejected by Pod Security:
  - update securityContext and image user in charts before re-enforcing restricted labels.
- Trivy blocks too many builds initially:
  - adopt phased gating (report-only in dev, blocking in stage/prod) with explicit timeline.

## Done checklist

- Network access is least-privilege.
- Pod Security and resource limits are enforced.
- CI blocks high-risk vulnerabilities.
- Budget notifications are active.
