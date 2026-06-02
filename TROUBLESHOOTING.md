# Troubleshooting

Symptom-based index for **Online Boutique on Azure**. Deployment setup: [DEPLOYMENT.md](DEPLOYMENT.md). Architecture: [ARCHITECTURE.md](ARCHITECTURE.md).

---

## Quick index

| Symptom | Likely cause | Action |
|---------|--------------|--------|
| Pipeline fails at “Missing role AcrPull” | Promotion SP missing ACR/RG roles | [DEPLOYMENT.md — Promotion SP roles](DEPLOYMENT.md#promotion-service-principal-roles) |
| Pipeline fails creating GitHub PR | Missing/invalid `GITHUB_TOKEN` | [Phase 3 §2c](docs/implementation/phase-03-first-service-frontend.md#2c-variable-group-and-github_token-github-pr-step) |
| `ImagePullBackOff` | ACR not attached or wrong digest/registry | `az aks update --attach-acr <acr>`; check `gitops/envs/<env>/values-*.yaml` |
| Argo app **OutOfSync** / **Unknown** | Wrong chart path, repo URL, or values | `kubectl describe application -n argocd <name>` |
| Prod not updating after PR merge | Prod uses **manual** sync | Argo CD UI → **Sync** prod app |
| HTTPS certificate not ready | DNS or DNS-01 challenge | [certificate-renewal-expiry](docs/runbooks/certificate-renewal-expiry.md) |
| Storefront **503** / wrong backend | `googleDemo.enabled: true` without demo services | Set `googleDemo.enabled: false` in env values |
| Ingress **5xx** | Backend down, policy block, controller issue | [ingress-5xx-triage](docs/runbooks/ingress-5xx-triage.md) |
| Placeholders still in cluster | `YOUR_TENANT_ID` etc. not replaced | [DEPLOYMENT.md — Fork setup](DEPLOYMENT.md#fork-setup-replace-placeholders) |
| Terraform backend error | Wrong `backend.hcl` | [Phase 1](docs/implementation/phase-01-terraform-foundation.md), bootstrap README |

---

Detailed procedures: [docs/runbooks/README.md](docs/runbooks/README.md).

---

## Azure DevOps

| Issue | Check |
|-------|--------|
| Wrong repo checked out | Pipeline **Edit** → header **Repository** / **Branch** |
| After GitHub rename | [pipelines/README.md](pipelines/README.md#azure-devops-pipeline-source-after-a-github-rename) |
| Service connection not authorized | First run → **Permit** on `promotion-azure-connection` |
| Variable group not found | Name must be `variable-group-for-microservices` exactly |

---

## Kubernetes (common commands)

```bash
kubectl get applications -n argocd
kubectl get pods -n <dev|stage|prod>
kubectl describe pod -n <ns> <pod>
kubectl get certificate,challenge -A
kubectl get networkpolicy -n <ns>
az acr repository show-tags --name <ACR> --repository <service> -o table
```

---

## Terraform

```bash
az account show
terraform init -backend-config=backend.hcl
terraform plan
```

State bootstrap: [infra/terraform/envs/bootstrap/README.md](infra/terraform/envs/bootstrap/README.md).

---

## Smoke tests

See [scripts/README.md](scripts/README.md).

---

## Escalation

Prod GitOps approvers: [docs/gitops/prod-branch-protection.md](docs/gitops/prod-branch-protection.md).
