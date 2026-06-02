# Key Vault + CSI secrets (v1)

v1 wires **frontend** in each environment to its env Key Vault using **Workload Identity** and the **AKS Key Vault Secrets Provider** add-on.

## What ships in this repo

| Layer | Artifact |
|-------|----------|
| AKS | `key_vault_secrets_provider` on cluster ([`modules/aks`](../../infra/terraform/modules/aks/main.tf)) |
| Terraform (per env) | UAMI + federated credential + **Key Vault Secrets User** ([`modules/workload_identity`](../../infra/terraform/modules/workload_identity)) |
| GitOps (dev) | [`SecretProviderClass`](../../gitops/platform/dev/secret-provider-class-frontend.yaml) synced by `platform-dev` |
| Helm | Optional `workloadIdentity` / `keyVault` in [`charts/frontend`](../../charts/frontend/values.yaml) (off by default) |

Stage/prod have Terraform identities and subjects aligned to `frontend-stage` / `frontend-prod` service accounts. Copy the dev `SecretProviderClass` pattern to `gitops/platform/stage/` and `gitops/platform/prod/` when you enable CSI there.

## Apply order (dev example)

### 1. Terraform

```bash
# Shared stack first (enables CSI add-on on AKS — may update cluster in place)
cd infra/terraform/envs/shared && terraform apply

cd ../dev && terraform apply
terraform output -raw frontend_workload_identity_client_id
```

### 2. Sample secret in Key Vault

```bash
az keyvault secret set \
  --vault-name kv-boutique-dev-weu \
  --name boutique-sample \
  --value "hello-from-kv"
```

### 3. GitOps placeholders

Edit `gitops/platform/dev/secret-provider-class-frontend.yaml`:

- `YOUR_TENANT_ID` → `az account show --query tenantId -o tsv`
- `YOUR_DEV_FRONTEND_UAMI_CLIENT_ID` → terraform output above

Commit; Argo CD `platform-dev` syncs the class.

### 4. Enable frontend chart mount (optional)

In `gitops/envs/dev/values-frontend.yaml`:

```yaml
workloadIdentity:
  enabled: true
  clientId: "<frontend_workload_identity_client_id>"

keyVault:
  enabled: true
  secretProviderClass: boutique-dev-frontend-kv
```

Merge; Argo syncs `frontend-dev`. Verify mount:

```bash
kubectl exec -n dev deploy/frontend -- cat /mnt/secrets-store/boutique-sample 2>/dev/null || \
  kubectl exec -n dev deploy/frontend -- ls /mnt/secrets-store
```

Synced Kubernetes secret (optional): `boutique-sample-k8s` from `secretObjects` in the class.

## Federated subjects (must match ServiceAccount names)

| Env | Helm `releaseName` | SA name | Terraform `federated_subject` |
|-----|-------------------|---------|-------------------------------|
| dev | `frontend` | `frontend` | `system:serviceaccount:dev:frontend` |
| stage | `frontend-stage` | `frontend-stage` | `system:serviceaccount:stage:frontend-stage` |
| prod | `frontend-prod` | `frontend-prod` | `system:serviceaccount:prod:frontend-prod` |

## Troubleshooting

| Symptom | Check |
|---------|--------|
| `FailedToMount` on pod | AKS add-on installed; `SecretProviderClass` clientID/tenantId; secret exists in vault |
| `403` from Key Vault | UAMI has **Key Vault Secrets User** on vault; federated subject matches SA |
| No egress | Dev NetworkPolicy allows TCP 443 to `0.0.0.0/0` (private endpoint resolves via Azure) |

## Not in v1

- CSI for cartservice, redis, etc.
- Automatic rotation consumers beyond add-on defaults
- Populating all app secrets from Google demo into Key Vault

See [SECURITY.md](../../SECURITY.md) and [ADR-002](../adr/ADR-002-platform-bootstrap-helm-vs-argo.md).
