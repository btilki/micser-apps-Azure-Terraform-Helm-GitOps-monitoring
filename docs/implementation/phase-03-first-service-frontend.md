# Phase 3 — First service (`frontend`)

[← Phase 2](phase-02-cluster-bootstrap.md) · [Index](README.md) · [Phase 4 →](phase-04-promotion-pipeline.md)

**Goal:** Build → dev ACR → GitOps digest → Argo CD → HTTPS on dev hostname.

---

## Implementation

> **Use:** Editor/IDE, **Git** (branches, PRs), **Helm**, **Azure DevOps Pipelines** (or GitHub Actions), **Azure Portal/CLI** (ACR, service connections), **Argo CD UI**, browser for HTTPS test.

1. **Source** — Add `apps/frontend` (copy from [microservices-demo](https://github.com/GoogleCloudPlatform/microservices-demo) or use subtree; see `apps/README.md`).

2. **Helm** — Create `charts/frontend` (Deployment, Service, ServiceAccount; Ingress for dev; values for registry + **digest**, tolerations/nodeSelector for `env=dev`).

3. **GitOps** — Add `gitops/apps/dev/frontend.yaml` (Argo CD `Application`) and `gitops/envs/dev/values-frontend.yaml` (dev ACR login server + placeholder digest).

4. **Register app** — Add a child Application under `gitops/bootstrap/applications/` (or your app-of-apps) so the root sync picks up `frontend`.

5. **Azure DevOps** — New pipeline from YAML: `pipelines/ci/frontend.yml` (create file): build image, run tests/lint, **Trivy**, push to **dev** ACR, output digest, script or task to open PR updating `gitops/envs/dev/values-frontend.yaml`. Configure **service connection** (ACR push, federated identity if used).

6. **Merge** GitOps PR — In Argo CD: app syncs; **Applications** → `frontend` healthy.

7. **TLS** — Ingress host matches cert (e.g. `dev.boutique.<domain>`); fix DNS/cert-manager if browser shows cert errors.

---

## Checklist

- [ ] `https://<dev-frontend-host>` returns 200.
- [ ] Pod image is `…@sha256:…` (digest), not a floating tag only.

---

## Your notes / extra steps

-
