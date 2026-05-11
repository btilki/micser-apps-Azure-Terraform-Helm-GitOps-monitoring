# Phase 1 — Terraform foundation

[← Phase 0](phase-00-repo-scaffolding.md) · [Index](README.md) · [Phase 2 →](phase-02-cluster-bootstrap.md)

**Goal:** Build Azure foundation (state, shared cluster/network, env stacks) and confirm `kubectl` access.

## Process (brief)

Authenticate to Azure, create Terraform remote state, deploy shared stack, deploy environment stacks (`dev`, `stage`, `prod`), then validate AKS and ACR access.

## Step-by-step

1. Prerequisites check:
   - Terraform and Azure CLI installed
   - rights to create resource groups, storage, AKS, ACR, DNS resources
   - correct repository branch checked out (`main` or your infra branch)
2. Login to Azure and select the correct subscription:
   ```bash
   az login
   az account list -o table
   az account set --subscription "<SUBSCRIPTION_ID_OR_NAME>"
   az account show -o table
   ```
3. Use `infra/terraform/envs/bootstrap` to deploy remote state:
   ```bash
   cd infra/terraform/envs/bootstrap
   cp terraform.tfvars.example terraform.tfvars
   # set storage_account_name in terraform.tfvars (globally unique)
   terraform init
   terraform plan
   terraform apply
   ```
4. Capture bootstrap outputs and fill `backend.hcl` for next stacks:
   - storage account name
   - container name
   - resource group name
   - key per environment
5. Use `infra/terraform/envs/shared` to deploy shared Azure resources:
   ```bash
   cd ../shared
   cp backend.hcl.example backend.hcl
   # fill backend.hcl using bootstrap outputs
   terraform init -backend-config=backend.hcl
   terraform plan
   terraform apply
   ```
6. Delegate DNS at registrar:
   - use `terraform output dns_zone_name_servers` from shared stack
   - update NS records at your domain provider
   - wait for propagation before TLS steps in later phases
7. Deploy environment stacks in order (`dev`, then `stage`, then `prod`):
   ```bash
   cd ../dev   # then repeat for ../stage and ../prod
   cp backend.hcl.example backend.hcl
   cp terraform.tfvars.example terraform.tfvars
   # fill backend.hcl + terraform.tfvars for each env
   terraform init -backend-config=backend.hcl
   terraform plan
   terraform apply
   ```
8. Export kubeconfig from shared outputs and verify AKS access:
   ```bash
   cd ../shared
   terraform output -raw kube_config_raw > ~/.kube/config-boutique
   export KUBECONFIG=~/.kube/config-boutique
   kubectl get nodes
   kubectl get ns
   ```
9. Azure verification checks:
   ```bash
   az acr list -o table
   az group list --query "[?contains(name, 'rg-boutique')].name" -o table
   ```
10. GitHub and Azure DevOps follow-up:
   - commit generated infra configuration files that are meant to be versioned (exclude secrets/local-only files)
   - open PR in GitHub for Terraform changes
   - if using Azure DevOps Terraform pipeline, create/verify service connection with least privilege
   - ensure pipeline can read remote state storage account (Blob data-plane permissions)

## Done checklist

- Bootstrap, shared, and all env Terraform applies succeed.
- DNS delegation is correct.
- AKS is reachable with `kubectl`.
