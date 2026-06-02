# GitOps (Argo CD)

Layout (see [ARCHITECTURE.md](../ARCHITECTURE.md)):

| Path | Purpose |
|------|---------|
| `bootstrap/root-app.yaml` | Root `Application` (copy from `root-app.yaml.example`; points at `bootstrap/applications/`) |
| `bootstrap/applications/` | Child `Application` manifests (app-of-apps): `apps-dev`, `apps-stage`, `apps-prod`, `platform-*`, … |
| `apps/dev\|stage\|prod/` | Per-service Argo CD `Application` manifests (Helm chart path + env values file) |
| `apps/platform/` | **Helm values** for cert-manager, external-dns, kube-prometheus-stack — consumed by **Phase 2 `helm install`**, not separate Argo apps in `bootstrap/applications/` |
| `platform/` | Namespace policies synced by Argo (`platform-dev`, `platform-stage`, …): quotas, NetworkPolicies, optional ingress extras |
| `envs/dev\|stage\|prod/` | Helm value fragments (`image.repository`, `image.digest`, ingress host, …) updated by CI/promote PRs |

**Bootstrap order:** Install platform components with Helm ([phase-02](../docs/implementation/phase-02-cluster-bootstrap.md)), then `kubectl apply` the root app. **ingress-nginx** is Helm-only today (not an Argo `Application` under `bootstrap/applications/`).

**After you fork:** set `repoURL` in manifests to your GitHub or Azure Repos URL.
