# Online Boutique on Azure

Mono-repo for Google’s [microservices-demo](https://github.com/GoogleCloudPlatform/microservices-demo) on **Azure Kubernetes Service (AKS)** with **Terraform**, **Azure DevOps** CI/CD, **Argo CD** GitOps, and **kube-prometheus-stack** observability.

## Documentation

| Document | Description |
|----------|-------------|
| [ARCHITECTURE.md](ARCHITECTURE.md) | Azure/AKS topology, CI/CD, GitOps, diagrams |
| [DEPLOYMENT.md](DEPLOYMENT.md) | Install and operate (phased guide, fork setup, releases) |
| [SECURITY.md](SECURITY.md) | Policies, secrets, prod controls, supply chain |
| [TROUBLESHOOTING.md](TROUBLESHOOTING.md) | Common failures and runbook index |
| [ROADMAP.md](ROADMAP.md) | Scope, status, planned work |

Component references: [pipelines/](pipelines/README.md) · [gitops/](gitops/README.md) · [charts/](charts/README.md) · [apps/](apps/README.md) · [runbooks/](docs/runbooks/README.md)

## Prerequisites

| Tool | Purpose |
|------|---------|
| [Terraform](https://developer.hashicorp.com/terraform/install) ≥ 1.5 | `infra/terraform/` |
| [Azure CLI](https://learn.microsoft.com/cli/azure/install-azure-cli) | Login, ACR, AKS, RBAC |
| `kubectl`, [Helm](https://helm.sh/docs/intro/install/) 3 | Cluster bootstrap and chart checks |
| Git | PR workflow |
| Azure subscription | RG, AKS, ACR, DNS |
| Domain (optional) | TLS via Azure DNS + cert-manager |
| [Azure DevOps](https://azure.microsoft.com/products/devops) | CI and promotion pipelines |
| [GitHub](https://github.com) (recommended) | Source + GitOps PRs from pipelines |

Full list and verification commands: [DEPLOYMENT.md — Prerequisites](DEPLOYMENT.md#prerequisites).

## Quick start

1. **Clone** and complete [DEPLOYMENT.md — Fork setup](DEPLOYMENT.md#fork-setup-replace-placeholders).
2. [Phase 0](docs/implementation/phase-00-repo-scaffolding.md) — branch protection, CODEOWNERS.
3. [Phase 1](docs/implementation/phase-01-terraform-foundation.md) → [Phase 2](docs/implementation/phase-02-cluster-bootstrap.md) — infra and platform.
4. [Phase 3](docs/implementation/phase-03-first-service-frontend.md) — first CI pipeline and dev HTTPS.
5. [Phases 4–7](DEPLOYMENT.md#phased-deployment-guide) — promote to stage/prod.

## Repository layout

| Path | Purpose |
|------|---------|
| `infra/terraform/` | Bootstrap, shared, dev/stage/prod stacks |
| `gitops/` | Argo CD app-of-apps, env values |
| `pipelines/` | Azure DevOps CI and promote YAML |
| `charts/` | Helm charts per service |
| `apps/` | Docker build contexts |
| `scripts/` | Smoke tests |
| `docs/implementation/` | Phased deployment steps (linked from DEPLOYMENT.md) |
| `docs/runbooks/` | Incident procedures (linked from TROUBLESHOOTING.md) |

## License

See [LICENSE](LICENSE).
