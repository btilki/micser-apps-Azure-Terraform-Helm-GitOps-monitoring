# Medium draft — Part 3 of 3

**Suggested title:** Promote by Digest, Gate Production, and Operate: GitOps Release Day on Azure  
**Subtitle:** Part 3 of 3 — Stage and prod promotion, manual Argo sync, observability, and rollback without breaking the contract  
**Tags (pick 5):** DevOps, GitOps, Azure, Kubernetes, Argo CD, SRE, CI/CD, Platform Engineering  
**Repo link (use in story):** https://github.com/btilki/micser-apps-Azure-Terraform-Helm-GitOps-monitoring  

**Images to upload to Medium (from repo `docs/diagrams/`):**  
1. `01-cicd-flow.png` — promotion section  
2. `azure-devops-pipelines-environments-promote-stage-prod.png` — ADO environment approvals  
3. `00-platform-overview.png` — closing "full loop" recap (optional)  

---

*Part 3 of 3. [Part 1](post-01-architecture-and-choices.md) — architecture. [Part 2](post-02-deploy-from-zero-to-dev-https.md) — deploy through dev HTTPS.*

---

You have dev serving traffic over HTTPS and an image digest recorded in Git. The interesting engineering starts when you refuse to rebuild for stage and prod—and when you refuse to let a green Git commit trigger prod automatically.

This article walks through **promotion** (`az acr import` + GitOps PRs), why **production Argo CD sync is manual**, how **observability and runbooks** fit the model, and how to **roll back** without abandoning the GitOps contract.

**Repository:** https://github.com/btilki/micser-apps-Azure-Terraform-Helm-GitOps-monitoring  

---

## The release contract (recap)

Three steps, three tools:

| Step | Tool | What changes |
|------|------|----------------|
| Build / scan / push | Azure DevOps CI | Image in **dev** ACR; PR to `gitops/envs/dev/values-*.yaml` |
| Promote | `promote-to-stage.yml` / `promote-to-prod.yml` | Import digest to target ACR; PR to stage/prod values |
| Deploy | Argo CD | Helm apply from `charts/` + env values |

The digest string in Git is the contract. Promotion copies **manifests**, not tags you might retag later.

**[Insert image: 01-cicd-flow.png — caption: Import by digest across ACRs; GitOps PRs are the audit trail.]**

---

## Promote to stage

Pipelines live under `pipelines/promote/`. Shared logic is in `pipelines/templates/promote-image.yml`:

1. **RBAC pre-check** — fails if the service principal cannot read the source ACR and push to the target ACR (and required resource groups).
2. **`az acr import`** — copies the image manifest from dev ACR to stage ACR (or stage → prod in the prod pipeline).
3. **GitOps edit + GitHub PR** — updates `gitops/envs/stage/values-<service>.yaml` with the same `sha256:…` digest.

Register `promote-to-stage.yml` in Azure DevOps like CI: point at the YAML path, run manually, set parameter **`service`** (`frontend` first, then other v1 services).

**Azure DevOps environments:** Configure **`promote-stage`** with checks appropriate for your team (optional approvers, branch filters). Stage is where you rehearse "upper env" behavior without production risk.

After PR merge, Argo CD syncs stage apps (auto-sync is typical for stage). Verify:

```bash
az acr manifest list-metadata --registry <STAGE_ACR> --name frontend -o table
kubectl get pods -n stage
curl -sS -o /dev/null -w "%{http_code}\n" https://stage.boutique.example.com/
```

Confirm the digest in stage values matches dev for that promotion—parity is the point.

**[Insert image: azure-devops-pipelines-environments-promote-stage-prod.png — caption: Environment gates for promote-stage and promote-prod.]**

---

## Promote to prod (stricter on purpose)

Prod differs by design:

| Control | Why |
|---------|-----|
| **Manual Argo CD Sync** | Merging Git does not roll out prod; an operator syncs after review |
| **Separate prod ACR** | Kubelet pulls only from `acrboutiqueprodweu` (reference name) |
| **`boutique-prod` AppProject** | Limits repos and namespaces prod Applications may use |
| **CODEOWNERS + branch protection** | `gitops/envs/prod/**` and `gitops/apps/prod/**` need named approvers |
| **`promote-prod` environment approval** | Human gate before import runs |

Run `promote-to-prod.yml` with **`service`** set; complete the **promote-prod** approval; review the GitHub PR (only prod values should change; digest must match what you tested in stage).

Attach prod ACR to the cluster if you have not already:

```bash
az aks update -g rg-boutique-shared-weu -n aks-boutique-weu --attach-acr acrboutiqueprodweu
```

Merge the prod values PR—then in Argo CD UI or CLI, **Sync** each prod Application (`frontend-prod`, etc.). Prod manifests intentionally omit automated sync policy.

Verify with the [release-verification](https://github.com/btilki/micser-apps-Azure-Terraform-Helm-GitOps-monitoring/blob/main/docs/runbooks/release-verification.md) checklist: pods ready, ingress healthy, and no TLS errors.

Default URLs (replace `example.com`):

| Env | Storefront |
|-----|------------|
| dev | `https://dev.boutique.example.com` |
| stage | `https://stage.boutique.example.com` |
| prod | `https://boutique.example.com` |

---

## Identity and prod gates (practical view)

Three RBAC layers often get conflated:

- **Azure RBAC** — pipeline SP and kubelet identities on ACRs, DNS, Key Vault.
- **Kubernetes RBAC** — who can `kubectl` into which namespace (optional AAD groups).
- **Git + Argo** — who can merge prod GitOps and who may click **Sync**.

Prod secrets belong in **Key Vault** via Secrets Store CSI—not in Git. Platform controllers use **Workload Identity** (cert-manager, external-dns). CI uses **`promotion-azure-connection`** and a Library group secret for the prod ACR.

Longer treatment: `SECURITY.md` and `docs/gitops/prod-branch-protection.md`. Maintain a [prod known-good digest table](https://github.com/btilki/micser-apps-Azure-Terraform-Helm-GitOps-monitoring/blob/main/docs/runbooks/release-verification.md) in your runbook repo.

---

## Observability on release day

**kube-prometheus-stack** in `monitoring` scrapes ingress and workload metrics. Grafana dashboards (see `docs/runbooks/grafana-dashboards.md`) help answer: "Is this a bad deploy or a platform issue?"

Alertmanager routes worth configuring before prod traffic:

- Ingress **5xx** ratio bursts (`BoutiqueHighHttp5xxRatio` style rules).
- Pod **crash loops** after a new digest.
- **Certificate expiry** — cert-manager metrics; DNS-01 failures show up as TLS errors first.

Alerts do not replace verification—they narrow where to look when promotion and sync succeed but users still experience problems.

---

## Rollback without abandoning GitOps

**Preferred path:** Git revert or restore the previous **`image.digest`** in `gitops/envs/prod/values-<service>.yaml`, merge through prod branch protection (two reviewers if that is your rule), then sync prod app(s) in Argo CD.

Avoid `kubectl set image` except in emergencies—the cluster must match Git or the next sync will fight you.

Runbook flow (`docs/runbooks/prod-rollback.md`):

1. Note the time of the last prod values merge or manual Sync.
2. Compare the current digest to known-good (table, previous commit, or stage if stage was last good).
3. Open rollback PR; merge; Sync prod app(s).
4. `kubectl rollout status` and `curl` the storefront.

If Sync fails repeatedly or pods stay **CrashLoop** with the correct digest, escalate to platform (node, CNI, registry outage)—not another blind promote.

Other runbooks in the repo:

| Runbook | When |
|---------|------|
| [ingress-5xx-triage](https://github.com/btilki/micser-apps-Azure-Terraform-Helm-GitOps-monitoring/blob/main/docs/runbooks/ingress-5xx-triage.md) | HTTP errors at the edge |
| [certificate-renewal-expiry](https://github.com/btilki/micser-apps-Azure-Terraform-Helm-GitOps-monitoring/blob/main/docs/runbooks/certificate-renewal-expiry.md) | TLS / ACME issues |
| [failing-argocd-sync-prod](https://github.com/btilki/micser-apps-Azure-Terraform-Helm-GitOps-monitoring/blob/main/docs/runbooks/failing-argocd-sync-prod.md) | Prod app won't sync or stays unhealthy |

---

## Hardening after the first prod release

Phases 8–9 in the repo cover policy bundles, Trivy in CI, budgets, dashboard polish, and optional smoke steps in promote pipelines. You do not need everything on day one—but **NetworkPolicies**, **PodSecurityPolicy**, and **CertificatePolicy** should follow soon after.

---

## Full loop (what you built)

**[Optional: insert 00-platform-overview.png — caption: Developer → GitHub → Azure DevOps → ACRs → Argo CD → AKS.]**

From a whiteboard perspective you now have:

- Reproducible Azure foundation (Terraform layers).
- Build once in dev, **import** the same digest upward.
- GitOps PRs as audit trail; prod protected by review **and** manual sync.
- HTTPS, DNS automation, and metrics for day-two operations.

That is a credible platform engineering demo—not because it uses fashionable tools, but because the **artifact** (digest) and **contract** (Git) stay aligned across environments.

---

## Series close

| Part | Topic |
|------|--------|
| 1 | Architecture, three ACRs, cluster layout, scope |
| 2 | Terraform, bootstrap, first HTTPS on dev |
| 3 | Promote, prod gates, observe, rollback |

Clone the repo, open an issue if a step drifts from the docs, and extend v1 with upstream Online Boutique services when you want the full checkout path.

**Repository:** https://github.com/btilki/micser-apps-Azure-Terraform-Helm-GitOps-monitoring  

Thanks for following the series—operational reality lives in the runbooks and phase guides; I treat Medium as the narrative and GitHub as the source of truth.
