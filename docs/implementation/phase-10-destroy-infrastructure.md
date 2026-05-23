# Phase 10 — Destroy infrastructure (teardown)

[← Phase 9](phase-09-polish.md) · [Deployment](../../DEPLOYMENT.md)

**Goal:** Tear down all Terraform-managed Azure resources safely.

## Process (brief)

Destroy in reverse apply order so remote state remains available until the end.

## Step-by-step

### Prerequisites

1. Confirm teardown is approved and backup/retention requirements are satisfied.
2. Confirm correct subscription:
   ```bash
   az account show
   ```

### Argo CD / Kubernetes cleanup first

3. Optional but recommended: remove active app workloads first to reduce delete blockers (load balancers, PVC finalizers).

   # Stop Argo from recreating workloads
   ```bash
   kubectl -n argocd patch application boutique-root --type merge -p '{"spec":{"syncPolicy":null}}'
   ```

   # Delete app namespaces
   ```bash
   kubectl delete ns dev stage prod --ignore-not-found=true
   ```

   # If stuck Terminating, clear namespace finalizers
   ```bash
   for ns in dev stage prod; do
     kubectl get ns "$ns" -o json >/tmp/${ns}.json 2>/dev/null || continue
     jq '.spec.finalizers=[]' /tmp/${ns}.json >/tmp/${ns}-nofinalizer.json
     kubectl replace --raw "/api/v1/namespaces/${ns}/finalize" -f /tmp/${ns}-nofinalizer.json
   done
   ```

   # Verify cleanup
   ```bash
   kubectl get ns
   ```

### Azure / Terraform destroy order

4. Destroy environment stacks first (`dev`, `stage`, `prod`):
   ```bash
   cd infra/terraform/envs/dev   # then stage, prod
   terraform init -backend-config=backend.hcl
   terraform plan -destroy
   terraform destroy
   ```
5. Destroy shared stack after all env stacks are removed:
   ```bash
   cd infra/terraform/envs/shared
   terraform init -backend-config=backend.hcl
   terraform plan -destroy
   terraform destroy
   ```
6. Destroy bootstrap state stack last (never before other stacks):
   ```bash
   cd infra/terraform/envs/bootstrap
   terraform init
   terraform plan -destroy
   terraform destroy
   ```
7. Verify in Azure Portal and CLI that project resource groups are removed/empty:
   ```bash
   az group list --query "[?contains(name, 'rg-boutique')].name" -o table
   ```

### Azure DevOps / GitHub follow-up

8. Disable or archive pipelines that target deleted infrastructure.
9. Merge teardown documentation PR (if you tracked teardown changes in docs/runbooks).

## Done checklist

- All env/shared/bootstrap stacks are destroyed successfully.
- No project resource groups remain unexpectedly.

---

[← Phase 9](phase-09-polish.md) · [Deployment](../../DEPLOYMENT.md)
