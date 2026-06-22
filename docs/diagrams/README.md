# Diagrams and screenshots

Assets for architecture docs, Medium articles, and phase guides.

## Architecture PNGs — in repo

| File | Source | Subject |
|------|--------|---------|
| `infrastructure-diagram.png` | [source/infrastructure-diagram.mmd](source/infrastructure-diagram.mmd) | Full platform: Terraform, Azure, AKS, workloads, GitOps |
| `architecture-cicd-sequence.png` | [source/architecture-cicd-sequence.mmd](source/architecture-cicd-sequence.mmd) | CI/CD sequence (build, promote, deploy) |

Shared render config: [source/mermaid-config.json](source/mermaid-config.json) (font size, spacing).

**Regenerate** after editing `.mmd` files:

```bash
./docs/diagrams/render-architecture-pngs.sh
```

Requires Node.js (`npx` downloads `@mermaid-js/mermaid-cli` once). The infrastructure diagram renders at high resolution (5200×3600 canvas, 2× scale).

Referenced from [ARCHITECTURE.md](../../ARCHITECTURE.md), [architecture-diagram.md](../architecture-diagram.md), and `docs/medium/post-*.md`.

## Azure DevOps screenshots — in repo

| File | Used in |
|------|---------|
| `azure-devops-settings-service-connections.png` | Phase 4, Medium Part 2 |
| `azure-devops-library-variable-group-github-token.png` | Phase 4, Medium Part 2 |
| `azure-devops-pipelines-environments-promote-stage-prod.png` | Phase 4, Medium Part 3 |
| `azure-devops-ci-pipeline-build-push-success.png` | Phase 4 |
| `azure-devops-pipelines-recent-runs.png` | Phase 4 |

## Walkthrough screenshots — in repo

Captured during real deploys; linked from `docs/implementation/phase-*.md`:

| File | Used in |
|------|---------|
| `boutique-frontend-dev.png` | Phase 3 |
| `boutique-frontend-dev-hot-products.png` | Phase 3 |
| `boutique-frontend-stage-hot-products.png` | Phase 6 |
| `boutique-frontend-prod-hot-products.png` | Phase 7 |
| `argocd-dev-apps-frontend-healthy.png` | Phase 5 |
| `argocd-applications-stage-dev-services-overview.png` | Phase 6 |
| `argocd-boutique-root-application-synced.png` | Optional — root app healthy |
| `grafana-dashboards-browse-kubernetes.png` | Phase 9 |
| `grafana-kubernetes-api-server-dashboard.png` | Phase 9 |
