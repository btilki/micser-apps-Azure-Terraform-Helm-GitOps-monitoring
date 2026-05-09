# Phase 7 — Prod environment

[← Phase 6](phase-06-stage-environment.md) · [Index](README.md) · [Phase 8 →](phase-08-hardening.md)

**Goal:** Prod GitOps, **manual** Argo CD sync for prod, alerts, short runbooks.

---

## Implementation

> **Use:** **Argo CD** (projects, sync policy manual, RBAC), **Git** (strict PR rules for `gitops/envs/prod/**`), **Helm values**, **Alertmanager** config (YAML + reload), **Grafana** UI optional, `docs/runbooks/`.

1. **GitOps** — `gitops/apps/prod/*`, `gitops/envs/prod/*`: prod ACR, turn off `loadgenerator`, higher replicas/PDBs.

2. **Argo CD** — **AppProject** `boutique-prod`: disable auto-sync; restrict who can **Sync** (Argo CD **RBAC** / SSO groups).

3. **Alertmanager** — In Prometheus stack values: set **receiver** (email, Slack webhook, etc.); apply; send test alert.

4. **Runbooks** — Add `docs/runbooks/` entries: rollback = revert GitOps PR + sync; cert expiry; ingress 5xx.

5. **Promote-to-prod** — Run pipeline with approvals; merge prod GitOps PR; **operator clicks Sync** in Argo CD for prod.

---

## Detailed step-by-step guide (practical)

This phase creates a controlled production path with human approvals and explicit sync actions.

### 0) Pre-checks before enabling prod

1. Confirm stage is stable and recently tested.
2. Confirm prod namespace and ACR exist:
   ```bash
   kubectl get ns
   az acr list -o table
   ```
3. Confirm promote pipeline for prod is configured with approvals:
   - `pipelines/promote/promote-to-prod.yml`
4. Confirm **DNS** and **TLS** for prod hostnames (GitOps does not create public DNS records):
   - **DNS target:** Each prod hostname (see step 5) must resolve to the **nginx ingress** front door for the cluster where **`prod`** workloads run—same idea as stage. In your DNS provider, point the name at the ingress controller **Service** `LoadBalancer`:
     - **A** / **AAAA** record(s) to the published **IP** address(es), or
     - **CNAME** to the cloud **FQDN** of that load balancer (for an apex host, use your provider’s **ALIAS/ANAME** if CNAME is not allowed).
   - **Discover the target** once the ingress controller is up and has an external IP or hostname, for example:
     ```bash
     kubectl get svc -A | grep -i ingress
     ```
     (Use the namespace and Service name for your install—often `ingress-nginx` / `ingress-nginx-controller`.)
   - **Certificates:** Prod Helm values use **cert-manager** via the ingress annotation `cert-manager.io/cluster-issuer: letsencrypt-prod`. Ensure a **ClusterIssuer** named **`letsencrypt-prod`** exists in the cluster. **HTTP-01** must succeed, so **port 80** on each hostname must reach the ingress from the public internet. After deploy, verify with `kubectl get certificate -n prod` (and `kubectl describe certificate` if not Ready).

Do not proceed if stage is unstable.

### 1) Create prod namespace + baseline guardrails

1. Create namespace:
   ```bash
   kubectl create ns prod --dry-run=client -o yaml | kubectl apply -f -
   kubectl get ns prod
   ```
2. Add baseline manifests for `prod` (see `gitops/platform/prod/`):
   - `ResourceQuota` — `resourcequota.yaml`
   - `LimitRange` — `limitrange.yaml`
   - default `NetworkPolicy` — `networkpolicy-baseline.yaml` (ingress only from `prod` + `ingress-nginx`; adjust if your controller namespace differs)
   - optional `PriorityClass` — `priorityclass-boutique-prod-critical.yaml`; set `priorityClassName` in prod Helm values where charts support it (e.g. frontend)
3. Commit these to GitOps-managed paths (recommended: `gitops/platform/prod/`).

### 2) Create Argo CD AppProject for prod

Create `boutique-prod` AppProject manifest with:
- source repo restriction to your mono-repo
- destination restriction to `prod` namespace only
- optional deny-list for dangerous cluster-scoped resources

Apply and verify:
```bash
kubectl apply -n argocd -f gitops/apps/prod/project-boutique-prod.yaml
kubectl get appproject -n argocd
```

### 3) Register prod in bootstrap/app-of-apps

Create bootstrap entries so root sync discovers prod resources:
- `gitops/bootstrap/applications/platform-prod.yaml` -> points to `gitops/platform/prod`
- `gitops/bootstrap/applications/apps-prod.yaml` -> points to `gitops/apps/prod`

Then hard refresh root and verify:
```bash
kubectl -n argocd annotate application boutique-root argocd.argoproj.io/refresh=hard --overwrite
kubectl get applications -n argocd
```

### 4) Enforce manual sync for prod apps

For each prod `Application`:
- set `project: boutique-prod`
- remove/disable automated sync policy (`automated`) so sync is operator-triggered
- keep self-heal/prune behavior aligned with your change control policy

Verify with:
```bash
kubectl get applications -n argocd -o yaml | grep -n "prod\\|syncPolicy"
```

Expected: prod apps require manual Sync in Argo CD UI/CLI.

### 5) Create prod service manifests and values

For each service:
- `gitops/apps/prod/<service>.yaml`
- `gitops/envs/prod/values-<service>.yaml`

Prod-specific values:
- `image.repository: <prod-acr-login-server>/<service>`
- `image.digest: sha256:<promoted-digest>`
- higher replicas (relative to stage/dev)
- stronger resources and probes
- PodDisruptionBudget for critical services
- `nodeSelector` / `tolerations` for prod pool
- `loadgenerator.enabled: false`

Ingress host for the storefront should be prod-specific (for this repo convention):
- frontend: `boutique.biroltilki.art`

(There is no separate “API” ingress in the upstream Online Boutique model; gRPC services are internal `ClusterIP`.)

Point this hostname at your prod ingress **LoadBalancer** and ensure **`letsencrypt-prod`** + HTTP-01 work as described in **step 0.4**.

Start with services that already have charts in this repo (`frontend`, `redis-cart`, `productcatalogservice`, `currencyservice`, `cartservice`) to avoid Unknown sync status from missing chart paths.

### 6) Configure strict Git protections for prod paths

Repo reference: **[Prod branch protection & approver teams](../gitops/prod-branch-protection.md)** (CODEOWNERS + GitHub `main` settings).

On `main` branch policies:
- require **≥ 2** approving reviews (use with **Require review from Code Owners** so prod paths pull in owners below)
- require successful **status checks** (pipeline/CI on PRs)
- **Require conversation resolution** before merge
- **disallow direct push** to `main` (no bypass, or document exceptions)

**Approver groups (GitHub org teams — create and grant repo access):**

| Team | Purpose |
|------|---------|
| `btilki/prod-gitops-approvers` | Primary code owners for `gitops/envs/prod/**` and `gitops/apps/prod/**` |
| `btilki/prod-gitops-secondary` | Second reviewer / cab-style approval |

Root **`CODEOWNERS`** assigns both teams to those paths. Replace org/team slugs if your GitHub org is not `btilki`.

### 7) Configure Alertmanager notifications

Reference values file: **`gitops/apps/platform/kube-prometheus-stack/values.yaml`** (`kube-prometheus-stack` Helm chart).

It configures:
- **Receiver `boutique-on-call`:** Slack incoming webhook, SMTP email, and generic webhook (Teams / automation) — replace `REPLACE_*` placeholders or mount secrets.
- **Routes** for: **pod crash loops** (`KubePodCrashLooping`, `KubePodNotReady`, `KubeJobFailed`), **ingress 5xx / sustained error ratio** (`BoutiqueIngress5xxBurst`, `BoutiqueHighHttp5xxRatio`), **cert expiry** (`BoutiqueCertificateExpiresSoon` + cert-manager alert names if present). Default **severity** alerts also go to the same receiver; **Watchdog** / **InfoInhibitor** stay muted.
- **AKS:** default rules for etcd / scheduler / controller-manager **disabled** (control plane not scraped).

Apply (example):
```bash
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm upgrade --install kube-prometheus-stack prometheus-community/kube-prometheus-stack \
  -n monitoring --create-namespace \
  -f gitops/apps/platform/kube-prometheus-stack/values.yaml
kubectl get pods -n monitoring
```

**Ingress metrics:** custom rules expect `nginx_ingress_controller_requests` (NGINX Ingress ServiceMonitor / scrape).

**Cert-manager metrics:** enable cert-manager’s Prometheus integration so `certmanager_certificate_expiration_timestamp_seconds` exists.

**Test notification** (fires a synthetic alert to Alertmanager):
```bash
kubectl -n monitoring port-forward svc/kube-prometheus-stack-alertmanager 9093:9093
curl -sS -H "Content-Type: application/json" \
  -d '[{"labels":{"alertname":"BoutiqueManualTest","severity":"warning"},"annotations":{"summary":"Manual Alertmanager test"}}]' \
  http://127.0.0.1:9093/api/v2/alerts
```
Confirm delivery on Slack/email/webhook, then silence or wait for auto-resolve.

### 8) Runbooks (minimum operational set)

See **`docs/runbooks/README.md`** — index for:

- [prod rollback](../runbooks/prod-rollback.md)
- [ingress 5xx triage](../runbooks/ingress-5xx-triage.md)
- [certificate renewal / expiry](../runbooks/certificate-renewal-expiry.md)
- [failing Argo CD sync in prod](../runbooks/failing-argocd-sync-prod.md)

Each includes: **symptoms**, **immediate checks**, **rollback/mitigation**, **owner/escalation**.

### 9) Promote image to prod (controlled release)

**Pipelines (Azure DevOps, manual run):**

| Service | YAML |
|---------|------|
| Frontend | `pipelines/promote/promote-to-prod.yml` |

1. **Queue** the pipeline on `main` (or the branch your GitOps repo uses). Approve the **`promote-prod`** environment when prompted.
2. **Optional parameter:** **Digest to promote** — leave empty to read digest from **stage** values on the checked-out branch; or set full `sha256:…` if stage Git is not updated yet.
3. When the pipeline opens the GitHub PR, **review**:
   - Only **`gitops/envs/prod/values-<service>.yaml`** (or equivalent path) should change.
   - **`image.digest`**: full **`sha256:`** (64 hex chars), not a placeholder.
   - **`image.repository`**: **`acrboutiqueprodweu.azurecr.io/<service>`** (prod ACR login server for this repo).
4. Get **code review** per [branch protection](../gitops/prod-branch-protection.md), then **merge** the PR.

**Prod ACR name (this project):** `acrboutiqueprodweu`

Verify the digest exists in prod ACR after import (requires `az login` and registry access):

```bash
az acr manifest list-metadata \
  --registry acrboutiqueprodweu \
  --name frontend \
  -o table
```

Confirm the **digest** column matches **`gitops/envs/prod/values-frontend.yaml`** on `main` after merge (repeat for other owned services you promote the same way).

5. Continue to **§10 Manual Argo CD sync** — prod apps do not auto-sync.

### 10) Manual Argo CD sync (human gate)

After PR merge:
1. Open Argo CD UI.
2. Select prod app(s).
3. Click **Sync** intentionally (manual gate).
4. Watch rollout and health.

CLI checks:
```bash
kubectl get applications -n argocd
kubectl get pods -n prod
kubectl get ingress -n prod
```

### 11) Post-release verification

After **manual Argo Sync** (§10) and rollout settles (~2–5 minutes):

1. **External HTTP checks** (expect **200** / **301** / **302**, not **5xx**):
   ```bash
   curl -sS -o /dev/null -w "frontend HTTP %{http_code}\n" -I https://boutique.biroltilki.art/
   ```
   Optional TLS sanity:
   ```bash
   curl -I https://boutique.biroltilki.art/ 2>&1 | head -20
   ```

2. **App journey in browser:** open **https://boutique.biroltilki.art/** — load main flows (browse, cart if applicable). Watch devtools **Network** for failed calls to upstream gRPC services.

3. **Dashboards / alerts (15–30 minutes):** Grafana (e.g. **kube-prometheus-stack**), **Alertmanager** / on-call channel — no new **5xx** bursts, **crash loop**, or **cert** alerts tied to this release. Cross-check [ingress 5xx runbook](../runbooks/ingress-5xx-triage.md) if needed.

4. **Cluster stability — no restart spikes:**
   ```bash
   kubectl get pods -n prod
   kubectl get pods -n prod -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{range .status.containerStatuses[*]}{.restartCount}{" "}{end}{"\n"}{end}' | head -30
   ```
   Compare **RESTARTS** in `kubectl get pods` to your pre-release baseline; investigate any pod that keeps growing during the observation window.
   **CPU/memory** (requires **metrics-server**):
   ```bash
   kubectl top pods -n prod
   ```
   If `kubectl top` errors, install or repair **metrics-server** on the cluster; use **Azure Monitor** / **Grafana** node-exporter views as fallback.

5. **Optional:** `kubectl get certificate -n prod` — **Ready=True** for prod TLS objects.

### 12) Rollback procedure (must be rehearsed)

**Rehearse at least once** (tabletop or non-prod dry run): identify a “bad” digest, practice opening the rollback PR, **Sync** in Argo CD, and **curl** checks — see [prod rollback](../runbooks/prod-rollback.md).

If release is bad:

1. **Revert** the prod GitOps PR on `main`, **or** open a **new PR** that pins **`image.digest`** (and `repository` if wrong) in `gitops/envs/prod/values-<service>.yaml` to the **last known-good** value — from [prod known-good digests](../gitops/prod-known-good-digests.md), `git log`, or stage values after confirming stage is healthy.
2. **Merge** the rollback PR using your **expedited** review path (still meet minimum reviewers per policy, or temporarily loosen policy only per org process — document who can approve).
3. **Manual Sync** in Argo CD for the affected prod **`Application`**(s) (`*-prod` apps do not auto-sync).
4. **Validate recovery:**
   ```bash
   kubectl rollout status deployment/<release>-<workload> -n prod
   curl -sS -o /dev/null -w "%{http_code}\n" -I https://boutique.biroltilki.art/
   kubectl get pods -n prod
   ```

**Keep previous known-good digest documented** for fast rollback: maintain **`docs/gitops/prod-known-good-digests.md`** (or your wiki) after each good prod ship — **do not** rely only on memory or Git archaeology during an incident.

### 13) Definition of done for Phase 7

- Prod apps are managed via GitOps with `boutique-prod` project controls.
- Prod deployment requires both PR approval and manual sync action.
- Prod images are promoted digests from stage/prod pipeline (no rebuild).
- Alert notifications are tested and received.
- Runbooks exist and rollback flow is **rehearsed**; [known-good digests](../gitops/prod-known-good-digests.md) maintained after releases.
