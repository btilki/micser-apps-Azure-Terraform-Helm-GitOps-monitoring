# Diagrams and screenshots

Assets for architecture docs, Medium articles, and phase guides.

## Architecture PNGs (`00`–`03`) — in repo

| File | Source | Subject |
|------|--------|---------|
| `00-platform-overview.png` | [source/00-platform-overview.mmd](source/00-platform-overview.mmd) | End-to-end platform flow |
| `01-cicd-flow.png` | [source/01-cicd-flow.mmd](source/01-cicd-flow.mmd) | CI, GitOps, promotion |
| `02-azure-resources.png` | [source/02-azure-resources.mmd](source/02-azure-resources.mmd) | Terraform layers |
| `03-inside-cluster.png` | [source/03-inside-cluster.mmd](source/03-inside-cluster.mmd) | Namespaces on AKS |

**Regenerate** after editing `.mmd` files:

```bash
./docs/diagrams/render-architecture-pngs.sh
```

Requires Node.js (`npx` downloads `@mermaid-js/mermaid-cli` once).

Referenced from [ARCHITECTURE.md](../../ARCHITECTURE.md) and `docs/medium/post-01-*.md`.

## Azure DevOps screenshots — in repo

| File | Used in |
|------|---------|
| `azure-devops-settings-service-connections.png` | Phase 3–4, Medium Part 2 |
| `azure-devops-library-variable-group-github-token.png` | Phase 4, Medium Part 2 |
| `azure-devops-pipelines-environments-promote-stage-prod.png` | Phase 4, Medium Part 3 |
| `azure-devops-ci-pipeline-build-push-success.png` | Phase 4 |
| `azure-devops-pipelines-recent-runs.png` | Phase 4 |

## Walkthrough screenshots — in repo

Captured during real deploys; linked from `docs/implementation/phase-*.md`:

- `boutique-frontend-dev.png`, `boutique-frontend-dev-hot-products.png`
- `boutique-frontend-stage-hot-products.png`, `boutique-frontend-prod-hot-products.png`
- `argocd-dev-apps-frontend-healthy.png`, `argocd-applications-stage-dev-services-overview.png`, `argocd-boutique-root-application-synced.png`
- `grafana-dashboards-browse-kubernetes.png`, `grafana-kubernetes-api-server-dashboard.png`
