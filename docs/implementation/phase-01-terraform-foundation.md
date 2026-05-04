# Phase 1 — Terraform foundation

[← Phase 0](phase-00-repo-scaffolding.md) · [Index](README.md) · [Phase 2 →](phase-02-cluster-bootstrap.md)

**Goal:** State storage, shared Azure stack (VNet, AKS, DNS zone, …), three env stacks (ACR + Key Vault each), `kubectl` works.

---

## Implementation

> **Use:** Terminal (`az`, `terraform`, `kubectl`), **Azure Portal** (optional checks), domain registrar for NS delegation. Install Azure CLI and Terraform if missing.

1. **Azure login & subscription**
   ```bash
   az login
   az account set --subscription "<SUBSCRIPTION_ID_OR_NAME>"
   ```

2. **Unique names** — If defaults are taken, edit ACR names in `infra/terraform/envs/dev|stage|prod/main.tf` and Key Vault names in the same files (KV max 24 chars, globally unique).

3. **Bootstrap state (once)**
   ```bash
   cd infra/terraform/envs/bootstrap
   cp terraform.tfvars.example terraform.tfvars
   # terraform.tfvars: set storage_account_name (globally unique, lowercase, 3–24 chars)
   terraform init && terraform apply
   ```
   Note outputs: resource group name, storage account name, container names.

4. **Shared stack — backend file**
   ```bash
   cd ../shared
   cp backend.hcl.example backend.hcl
   ```
   Edit `backend.hcl` with bootstrap outputs. Optional: add `terraform.tfvars` for `kubernetes_version`, `dns_zone_name`, `api_server_authorized_ip_ranges` (your public IP CIDRs).

5. **Shared stack — apply**
   ```bash
   terraform init -backend-config=backend.hcl
   terraform apply
   ```
   Save outputs: name servers, ingress public IP, AKS name. Sensitive: `terraform output -raw kube_config_raw` when needed.

6. **DNS** — At your registrar for the zone (e.g. `biroltilki.art`), set **NS** records to the Azure name servers from Terraform output. Wait for propagation.

7. **Env stacks (`dev`, `stage`, `prod`)** — For each:
   ```bash
   cd infra/terraform/envs/dev   # then stage, prod
   cp backend.hcl.example backend.hcl
   cp terraform.tfvars.example terraform.tfvars
   ```
   Fill `backend.hcl` and `terraform.tfvars` (state storage + shared state pointers). Then:
   ```bash
   terraform init -backend-config=backend.hcl
   terraform apply
   ```

8. **Kubeconfig**
   ```bash
   cd ../shared
   terraform output -raw kube_config_raw > ~/.kube/config-boutique
   export KUBECONFIG=~/.kube/config-boutique
   kubectl get nodes
   ```

**Apply order:** `bootstrap` → `shared` → `dev` / `stage` / `prod`.

**Private ACR/KV:** If images or Key Vault are private-endpoint-only, pushing images or running Terraform against KV from your laptop may require VPN/Bastion/self-hosted agent in the VNet.

---

## Checklist

- [ ] `kubectl get nodes` shows node pools for system + dev + stage + prod.
- [ ] Portal: shared RG + three env RGs; three ACRs; three Key Vaults.
- [ ] Domain NS delegation points to Azure.
- [ ] Terraform state blobs exist in the storage account.

---

## Your notes / extra steps

-
