# GitOps (ArgoCD)

Layout matches `docs/architecture-design.md` §11:

| Path | Purpose |
|------|---------|
| `bootstrap/` | Root Argo CD `Application` (app-of-apps) |
| `apps/platform/` | Argo CD apps: ingress-nginx, cert-manager, external-dns, monitoring, … |
| `apps/dev|stage|prod/` | Argo CD apps per microservice for that environment |
| `envs/dev|stage|prod/` | Helm value fragments (image registry + digest, replicas, resources) |

**After you create the Git repo:** set `repoURL` in manifests to your **Azure Repos** or **GitHub** URL and install the bootstrap app (see `docs/implementation/phase-02-cluster-bootstrap.md`).
