# Phase 6 — Stage environment

[← Phase 5](phase-05-fan-out-services.md) · [Index](README.md) · [Phase 7 →](phase-07-prod-environment.md)

**Goal:** Stand up and validate a stable `stage` environment driven by GitOps.

## Process (brief)

Create stage platform/app manifests, enforce stage project boundaries in Argo CD, promote images from dev to stage, then validate stage URL and service health.

## Step-by-step

### Prerequisites

1. Ensure `dev` is stable and promotion from Phase 4 is working.
2. Ensure stage namespace exists:
   ```bash
   kubectl get ns stage
   ```

### Azure

3. Ensure Azure stage resources exist and are reachable:
   ```bash
   az acr list -o table
   ```
4. Use stage guardrail manifests under `gitops/platform/stage/` (synced by `platform-stage`): `namespace.yaml`, `resourcequota.yaml`, `limitrange.yaml`, and **`networkpolicy-baseline.yaml`** (ingress only from `stage` + `ingress-nginx`).

### GitHub / GitOps

5. Use `gitops/apps/stage/project-boutique-stage.yaml` and ensure:
   - source repo restricted to this mono-repo
   - destination namespace restricted to `stage`
6. Use app manifests under `gitops/apps/stage/` and values under `gitops/envs/stage/`:
   - repository should be stage ACR
   - digest must be `sha256:...`
7. Use bootstrap registrations in `gitops/bootstrap/applications/` so root app discovers stage resources.

### Azure DevOps

8. Azure DevOps setup check before promotion:
   - `promote-to-stage.yml` points to the correct stage ACR
   - pipeline identity can import image and create PR
   - stage environment approvals/checks are configured as intended
9. Run stage promotion pipeline in Azure DevOps:
   - `promote-to-stage.yml`
10. GitHub operation:
   - review promotion PR changes in `gitops/envs/stage/`
   - merge after reviewer approval

### Argo CD / Kubernetes validation

11. Argo CD operation:
   - verify stage apps are synced after merge
   - if needed, trigger sync from Argo UI
12. Verify stage runtime:
   ```bash
   kubectl get applications -n argocd
   kubectl get pods,svc,ing -n stage
   curl -I https://stage.boutique.biroltilki.art
   ```

### Troubleshooting

- Stage PR merged but no rollout:
  - verify app registration under `gitops/bootstrap/applications/` and root app sync status.
- Stage TLS issues:
  - verify DNS records and cert-manager certificate/challenge status.

## Done checklist

- Stage apps are `Synced/Healthy`.
- Stage images come from stage ACR and are pinned by digest.
- Stage endpoint is reachable with valid TLS.
