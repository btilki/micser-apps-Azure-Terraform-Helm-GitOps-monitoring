# Phase 5 — Fan-out remaining services

[← Phase 4](phase-04-promotion-pipeline.md) · [Index](README.md) · [Phase 6 →](phase-06-stage-environment.md)

**Goal:** Complete **v1** application coverage in `dev`: all **owned** services use this repo’s CI/GitOps; the **rest of the boutique path** uses **upstream Google** images.

## v1 scope (explicit)

- **Owned here (v1 = 5 workloads: 4 services + Redis):** `frontend`, `cartservice`, `currencyservice`, `productcatalogservice`, `redis-cart` — each has a chart under `charts/`; values under `gitops/envs/*/`, and CI under `pipelines/ci/` where applicable.
- **Upstream Google (5 + loadgen):** `checkoutservice`, `emailservice`, `paymentservice`, `shippingservice`, `recommendationservice`, and `loadgenerator` — run from published microservices-demo images (not promoted through this repo’s service pipelines). **`adservice`** is optional / later for v1.

## Process (brief)

For **owned** services, repeat the frontend pattern: chart → env values → Argo app → CI digest PR. Deploy **upstream** workloads from Google’s manifests or Helm when you need a full end-to-end demo. Roll out in small batches and validate service-to-service traffic.

## Step-by-step

1. Define rollout order for **owned** services (recommended):
   - `redis-cart`
   - `productcatalogservice`, `currencyservice`, `cartservice`
2. Deploy **upstream** slice when needed for full journeys:
   - `checkoutservice`, `emailservice`, `paymentservice`, `shippingservice`, `recommendationservice`
   - `loadgenerator` (non-prod only)
   - omit `adservice` in v1 unless you choose to add it from upstream
3. For each **owned** service, use/update existing repo structure:
   - Helm chart: `charts/<service>/`
   - Argo app manifest: `gitops/apps/dev/<service>-dev.yaml` (e.g. `cartservice-dev.yaml`, `metadata.name: cartservice-dev`)
   - Dev values: `gitops/envs/dev/values-<service>.yaml`
   - CI pipeline: `pipelines/ci/<service>.yml` (or shared template)
4. Ensure each **owned** service is registered in `gitops/bootstrap/applications/`.
5. Run CI per **owned** service and let CI open GitHub digest PRs.
6. Review and merge PRs in small batches (2-3 services), then verify:
   ```bash
   kubectl get applications -n argocd
   kubectl get pods -n dev
   kubectl get svc -n dev
   ```
7. Validate service-to-service traffic with a debug pod when needed (including calls into **upstream** namespace services if used).
8. Keep only `frontend` (or your ingress entrypoint) exposed with Ingress for public traffic in this phase.
9. Keep **`loadgenerator`** on upstream images and **disabled in prod** (dev/stage only).

## Done checklist

- Core services are deployed and healthy in `dev`.
- Images are pinned by digest in GitOps values.
- End-to-end storefront flow works in `dev`.
