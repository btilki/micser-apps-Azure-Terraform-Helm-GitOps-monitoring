# Phase 3 — First service (`frontend`)

[← Phase 2](phase-02-cluster-bootstrap.md) · [Index](README.md) · [Phase 4 →](phase-04-promotion-pipeline.md)

**Goal:** Build → dev ACR → GitOps digest → Argo CD → HTTPS on dev hostname.

---

## Implementation

> **Use:** Editor/IDE, **Git** (branches, PRs), **Helm**, **Azure DevOps Pipelines** (or GitHub Actions), **Azure Portal/CLI** (ACR, service connections), **Argo CD UI**, browser for HTTPS test.

1. **Source** — Add `apps/frontend` (copy from [microservices-demo](https://github.com/GoogleCloudPlatform/microservices-demo) or use subtree; see `apps/README.md`).

2. **Helm** — Create `charts/frontend` (Deployment, Service, ServiceAccount; Ingress for dev; values for registry + **digest**, tolerations/nodeSelector for `env=dev`).

3. **GitOps** — Add `gitops/apps/dev/frontend-dev.yaml` (Argo CD `Application`, `metadata.name: frontend-dev`) and `gitops/envs/dev/values-frontend.yaml` (dev ACR login server + placeholder digest).

4. **Register app** — Add a child Application under `gitops/bootstrap/applications/` (or your app-of-apps) so the root sync picks up `frontend`.

5. **Azure DevOps** — New pipeline from YAML: `pipelines/ci/frontend.yml` (create file): build image, run tests/lint, **Trivy**, push to **dev** ACR, output digest, script or task to open PR updating `gitops/envs/dev/values-frontend.yaml`. Configure **service connection** (ACR push, federated identity if used).

6. **Merge** GitOps PR — In Argo CD: app syncs; **Applications** → `frontend-dev` healthy.

7. **TLS** — Ingress host matches cert (e.g. `dev.boutique.<domain>`); fix DNS/cert-manager if browser shows cert errors.

---

## Detailed step-by-step guide (practical)

Use this as a concrete path from source code to a live HTTPS endpoint in `dev`.

### 0) Pre-checks (do once)

1. Confirm these are working:
   ```bash
   az account show
   kubectl get nodes
   kubectl get applications -n argocd
   ```
2. Confirm `dev` infrastructure exists (from Phase 1):
   ```bash
   cd infra/terraform/envs/dev
   terraform output
   ```
3. Confirm cluster bootstrap components from Phase 2 are healthy:
   ```bash
   kubectl get pods -n ingress-nginx
   kubectl get pods -n cert-manager
   kubectl get pods -n argocd
   ```

### 1) Add frontend source code

1. Put app code under:
   - `apps/frontend`
2. Ensure it can build locally:
   ```bash
   cd apps/frontend
   # use your runtime toolchain here (npm/mvn/go/etc.)
   ```
3. Add/update Dockerfile if missing:
   - Build artifact
   - Expose app port
   - Set non-root user if possible

### 2) Create Helm chart for frontend

1. Create chart:
   ```bash
   mkdir -p charts/frontend/templates
   ```
2. Add minimum templates:
   - `Deployment`
   - `Service`
   - `ServiceAccount`
   - `Ingress` (dev host)
3. In chart values, include:
   - `image.repository`
   - `image.digest` (preferred)
   - `ingress.host`
   - scheduling fields for dev pool:
     - `nodeSelector`
     - `tolerations`
4. Render check:
   ```bash
   helm template frontend charts/frontend -f gitops/envs/dev/values-frontend.yaml
   ```

### 3) Add GitOps app manifests

1. Create Argo CD `Application`:
   - `gitops/apps/dev/frontend-dev.yaml`
2. Create env values file:
   - `gitops/envs/dev/values-frontend.yaml`
3. Put initial image settings in values file:
   - `repository: <dev-acr-login-server>/frontend`
   - `digest: sha256:<placeholder>`
4. Register app under bootstrap path:
   - add child app manifest in `gitops/bootstrap/applications/`

### 4) Add CI pipeline for frontend

1. Create pipeline file:
   - `pipelines/ci/frontend.yml`
2. Pipeline stages should do:
   - checkout
   - app tests/lint
   - container build
   - Trivy scan
   - push image to dev ACR
   - capture pushed image digest
   - update `gitops/envs/dev/values-frontend.yaml` with new digest
   - open PR with that GitOps change
3. Configure Azure DevOps service connection:
   - rights to push to dev ACR
   - repo permissions to open PR

### 5) Validate pipeline output

After pipeline runs, confirm:

1. Image exists in ACR:
   ```bash
   az acr repository show-tags --name <DEV_ACR_NAME> --repository frontend -o table
   ```
2. GitOps PR contains digest update:
   - `image.digest: sha256:...`
3. Merge GitOps PR to `main`.

### 6) Argo CD deployment verification

1. In Argo CD UI:
   - `frontend-dev` app should become `Healthy` + `Synced`
2. CLI checks:
   ```bash
   kubectl get deploy,po,svc,ing -n dev
   kubectl describe ingress -n dev
   ```
3. Confirm running image uses digest (not only mutable tag):
   ```bash
   kubectl get pod -n dev -o jsonpath='{range .items[*]}{.metadata.name}{" => "}{.spec.containers[*].image}{"\n"}{end}'
   ```

### 7) HTTPS and DNS checks

1. Confirm DNS record for frontend host:
   ```bash
   nslookup <dev-frontend-host>
   ```
2. Confirm TLS certificate ready:
   ```bash
   kubectl get certificate -A
   kubectl get challenges.acme.cert-manager.io -A
   ```
3. Browser/curl test:
   ```bash
   curl -I https://<dev-frontend-host>
   ```
   Expect `200` or application redirect, and valid cert chain.

### 8) Troubleshooting quick map

- No external address on Ingress:
  - check `ingress-nginx-controller` service and public IP binding.
- DNS not resolving:
  - check external-dns logs and zone permissions.
- TLS not issuing:
  - check `ClusterIssuer`, cert-manager challenges, and DNS TXT record creation.
- Argo app OutOfSync:
  - check chart path/value file refs in `frontend-dev` Application.
- Image pull errors:
  - confirm ACR pull role for AKS kubelet identity.

### 8.1) Practical fixes captured during implementation

Use this checklist if your setup matches this repository and Azure subscription.

1. **Use the correct dev ACR name from Terraform**
   - In this repo, dev ACR is `acrboutiquedevweu` (`infra/terraform/envs/dev/main.tf`).
   - Keep CI/GitOps values aligned:
     - `DEV_ACR_NAME=acrboutiquedevweu`
     - `DEV_ACR_LOGIN_SERVER=acrboutiquedevweu.azurecr.io`
     - `image.repository: acrboutiquedevweu.azurecr.io/frontend`

2. **For Microsoft-hosted Azure DevOps agents, ACR must be reachable**
   - If CI cannot push/pull due to private networking, enable public access on dev ACR for this phase:
   - `infra/terraform/envs/dev/main.tf` → `public_network_access_enabled = true`
   - Keep ACR SKU pinned to Premium when toggling network access.

3. **Terraform remote state permissions can block plan/apply**
   - `403 AuthorizationPermissionMismatch` on `terraform_remote_state` means missing Blob data-plane rights.
   - Grant your operator identity `Storage Blob Data Reader`/`Contributor` on the tfstate storage account.

4. **Pipeline hardening notes**
   - Resolve digest after push and write digest to `gitops/envs/dev/values-frontend.yaml`.
   - Use authenticated Trivy scanning against ACR (token from `az acr login --expose-token`).
   - For bootstrapping/demo flows, Trivy can run report-only (`--exit-code 0`) and later be tightened.
   - Use inline git identity for CI commit (avoid global git config mutation on agents).
   - Open GitHub PR via API using `GITHUB_TOKEN` secret variable.

5. **Node scheduling gotcha**
   - Do not leave restrictive default selectors in chart values that merge unexpectedly.
   - Keep chart defaults neutral:
     - `nodeSelector: {}`
     - `tolerations: []`
   - Set environment-specific scheduling in `gitops/envs/dev/values-frontend.yaml`:
     - `nodeSelector.kubernetes.azure.com/mode: user`

6. **InvalidImageName usually means placeholder digest is still in use**
   - If pods reference `sha256:replace-with-ci-produced-digest`, merge the digest PR (or update digest manually) and re-sync Argo.
   - Verify with:
   ```bash
   kubectl get pod -n dev -o jsonpath='{range .items[*]}{.metadata.name}{" => "}{.spec.containers[*].image}{"\n"}{end}'
   ```

7. **TLS/cert-manager DNS-01 fix for this repo**
   - DNS A record for `dev.boutique.biroltilki.art` must point to ingress public IP.
   - cert-manager must use Azure Workload Identity with the same client ID as ClusterIssuer managed identity:
     - ServiceAccount annotation: `azure.workload.identity/client-id: <MI_CLIENT_ID>`
     - Pod label: `azure.workload.identity/use: "true"`
   - Persist this in repo values to avoid drift: `gitops/apps/platform/cert-manager/values.yaml`.
   - If challenge reason shows `Identity not found`/`ManagedIdentityCredential authentication failed`, verify:
     - federated credential subject: `system:serviceaccount:cert-manager:cert-manager`
     - identity has `DNS Zone Contributor` on `biroltilki.art`
   - Re-check:
   ```bash
   kubectl get challenges.acme.cert-manager.io -A
   kubectl get certificate -A
   curl -I https://dev.boutique.biroltilki.art
   ```

8. **Ingress reachability diagnostic (when DNS is correct but HTTPS times out)**
   - Validate ingress-nginx service, endpoints, and Azure LB rules:
   ```bash
   kubectl get svc -n ingress-nginx
   kubectl describe svc ingress-nginx-controller -n ingress-nginx
   kubectl get endpoints -n ingress-nginx ingress-nginx-controller
   az network lb rule list -g MC_rg-boutique-shared-weu_aks-boutique-weu_westeurope --lb-name kubernetes -o table
   ```
   - If `curl` to both HTTP and HTTPS still times out while pods/certs are healthy, set Azure LB probe path on ingress-nginx service:
   ```bash
   kubectl annotate svc ingress-nginx-controller -n ingress-nginx \
     service.beta.kubernetes.io/azure-load-balancer-health-probe-request-path=/healthz \
     --overwrite
   ```
   - Persist the same annotation in your ingress-nginx Helm values (Phase 2) so future reconciliations keep it.

### 9) Definition of done for Phase 3

- `frontend` is managed by Argo CD from GitOps manifests.
- CI pipeline pushes image to dev ACR and updates digest in GitOps via PR.
- `https://<dev-frontend-host>` is reachable with valid TLS.
- Workload runs on intended `dev` nodes via selectors/tolerations.
