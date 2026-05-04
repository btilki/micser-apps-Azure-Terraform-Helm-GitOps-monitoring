# Project Walkthrough — Interview Brief

A short, interview-friendly explanation of the project. Read this end-to-end in ~5 minutes; use the Q&A at the bottom for likely follow-up questions.

> **Project:** End-to-end CI/CD platform for a microservices application on Azure.
> **Application:** Google's *Online Boutique* — 11 polyglot microservices (Go, Python, Node, Java, C#) plus Redis.
> **Environments:** dev, stage, prod (single AKS cluster, namespace-isolated).
> **Region:** West Europe.
> **Domain:** `biroltilki.art` (HTTPS via Let's Encrypt).

---

## 1. The 30-second elevator pitch

I built a production-style platform that automatically builds, scans, deploys, and monitors a microservices application on Azure Kubernetes Service. Code pushed to GitHub flows through Azure DevOps for CI, lands in environment-scoped Azure Container Registries, and is reconciled into a Kubernetes cluster by ArgoCD using GitOps. All Azure infrastructure is provisioned with Terraform; secrets live in Azure Key Vault and are mounted into pods through the CSI Secrets Store driver; observability is delivered by Prometheus and Grafana. Promotion between environments is a Git-driven, "build once, promote artifact" workflow.

---

## 2. What problem this solves

Modern teams need:

- **Consistent, repeatable infrastructure** — manual Azure clicks don't scale and aren't auditable.
- **A safe path from code to prod** — every change should be tested, scanned, and gated.
- **Strong env separation** — a dev mistake must not touch prod.
- **Observability and security as first-class concerns**, not afterthoughts.

This project demonstrates all four with a real, deployable architecture.

---

## 3. Infrastructure at a glance

**Single Azure subscription, one region (West Europe), one AKS cluster, three namespaces.**

| Layer | Components |
|---|---|
| Source control | GitHub (mono-repo) |
| CI/CD | Azure DevOps + ArgoCD |
| Container runtime | AKS (Azure CNI Overlay, Workload Identity, AAD-integrated) |
| Image registry | 3 × Azure Container Registry (one per environment) |
| Secrets | 3 × Azure Key Vault, mounted via CSI Secrets Store |
| Networking | VNet + private endpoints for ACR/KV; NGINX Ingress + cert-manager for HTTPS |
| DNS | Azure DNS (`biroltilki.art`); cert-manager uses DNS-01 against this zone |
| Observability | Prometheus, Grafana, Alertmanager, Azure Log Analytics |
| IaC | Terraform with remote state in Azure Storage |

---

## 4. The tool stack — what each does (one line each)

**Source & development**
- **GitHub** — mono-repo for app code, Helm charts, GitOps manifests, Terraform.
- **Cursor IDE** — local development environment.

**CI/CD**
- **Azure DevOps** — runs build pipelines and the cross-registry promotion pipeline.
- **Trivy** — scans images for HIGH/CRITICAL CVEs in CI; gates on failures.
- **ArgoCD** — in-cluster GitOps controller; reconciles cluster state to Git.

**Containers & orchestration**
- **Docker** — builds container images in CI.
- **Azure Container Registry (ACR)** — three env-scoped registries (dev/stage/prod).
- **Azure Kubernetes Service (AKS)** — managed Kubernetes runtime.
- **Helm** — package and templating for K8s manifests, one chart per microservice.

**Networking, ingress, TLS**
- **Azure VNet + NSG** — network foundation; private endpoints keep ACR/KV traffic internal.
- **NGINX Ingress Controller** — L7 ingress, TLS termination, HTTP→HTTPS redirect.
- **cert-manager** — issues TLS certs from Let's Encrypt via DNS-01 against Azure DNS.
- **Let's Encrypt** — public ACME certificate authority.
- **external-dns** — auto-creates A records in Azure DNS based on Ingress objects.
- **Azure DNS** — public zone for `biroltilki.art`.

**Identity & secrets**
- **Azure AD (Entra ID)** — identity provider; AAD groups bind to K8s RBAC.
- **User-Assigned Managed Identities (UAMIs)** — Azure identities, one per env + service.
- **Workload Identity (federated credentials)** — bridges K8s ServiceAccounts → UAMIs via OIDC; no secrets in pods.
- **Azure Key Vault** — env-scoped secret storage, RBAC mode, private endpoint, prod with purge protection.
- **CSI Secrets Store driver + Azure provider** — mounts Key Vault secrets as files in pods.

**IaC**
- **Terraform** — provisions all Azure resources; modules per service, env stacks per environment.
- **Azure Storage** — remote Terraform state (versioned, soft-deleted).

**Observability**
- **Prometheus + Alertmanager** — metrics scraping and alert routing.
- **Grafana** — dashboards.
- **Azure Log Analytics** — container logs and AKS control-plane diagnostics.

**Cluster security**
- **Pod Security Standards, NetworkPolicies, ResourceQuotas** — built-in K8s controls used per env.

---

## 5. How a code change reaches a user (end-to-end)

1. **Developer pushes** a change to GitHub.
2. **Azure DevOps CI** triggers: lints, tests, builds the container image, runs **Trivy**, pushes the image to **ACR dev**, then opens a PR bumping the image digest in `gitops/envs/dev/`.
3. **ArgoCD** notices the GitOps change and **syncs** the dev namespace — auto-sync, auto-prune, self-heal.
4. **Promotion to stage** is a separate pipeline: `az acr import` copies the **same digest** from ACR dev to ACR stage, then opens a PR in `gitops/envs/stage/`. After approval, ArgoCD syncs stage.
5. **Promotion to prod** repeats the same shape; prod requires manual ArgoCD sync after PR approval.
6. **Inside the cluster**, the kubelet pulls the image from the env-specific ACR using its managed identity (no pull secrets); pods mount secrets from the env-specific Key Vault via CSI; **NGINX Ingress** terminates TLS using a wildcard cert issued by **cert-manager** through Let's Encrypt; **external-dns** has already pointed `boutique.biroltilki.art` at the static public IP.
7. **The end user** opens the URL over HTTPS — request hits the public IP, NGINX routes to the frontend Service, traffic flows through the gRPC mesh of microservices, returns. **Prometheus** is scraping the whole time; logs ship to Log Analytics.

---

## 6. Key design decisions (and trade-offs)

- **Single AKS cluster + namespace isolation** — saves money and ops overhead vs. one cluster per env. Higher blast radius mitigated by per-env node pools (taints + nodeSelectors), per-env RBAC, NetworkPolicies (default-deny), ResourceQuotas, and Pod Security Standards.
- **One ACR per environment** — slightly more cost (~$60/mo for 3 ACRs vs $20 for one), but hard isolation between envs. Promotion uses `az acr import` of the **immutable digest**, so what runs in prod is byte-identical to what passed stage.
- **GitOps via ArgoCD app-of-apps** — Git is the single source of truth; rollback is `git revert`. Per-env sync policies (auto for dev, manual for prod) match the risk profile.
- **Workload Identity + Key Vault + CSI** — eliminates static credentials in the cluster. No PATs, no image-pull secrets, no .env files.
- **DNS-01 over HTTP-01 for Let's Encrypt** — enables wildcard certs and works even if Ingress isn't yet public.
- **Mono-repo** — simpler refactors and a single source of truth, with CODEOWNERS and path-scoped pipelines to manage blast radius.

---

## 7. What I'd improve next (shows growth mindset)

- **Service mesh** (Istio or Linkerd) for mTLS between microservices and finer-grained traffic control.
- **Image signing** with cosign + Kyverno admission policy to enforce signed-only images in prod.
- **Multi-region active-active** — currently single-region; pair West Europe with North Europe.
- **Automated promotion** via ArgoCD Image Updater or Renovate, instead of manual PRs.
- **Cost guardrails** — Azure Budget integrated with Slack; auto scale-to-zero on dev outside work hours.
- **Disaster recovery drill** — actually run a full Terraform-from-scratch rebuild and time it.

---

## 8. Quick-fire Q&A (likely interview questions)

**Q: Why AKS instead of self-managed Kubernetes?**
A: Managed control plane is free, AAD integration is native, Azure CNI Overlay is built in, and Workload Identity is first-party. Self-managing K8s wastes weeks I'd rather spend on the platform on top.

**Q: Why one cluster instead of three?**
A: Cost and ops overhead at this scale. The blast-radius downside is real but mitigated with namespace + node-pool + RBAC + NetworkPolicy isolation. For a regulated workload I'd revisit and split.

**Q: Why Terraform over Bicep / Pulumi?**
A: Provider ecosystem, community modules, broad team familiarity, and clean module composition. Bicep is fine for Azure-only shops; I went Terraform for portability.

**Q: How do you promote an image from dev to prod?**
A: I never rebuild — `az acr import` copies the immutable digest from dev's ACR into stage's, then prod's. Helm values reference images by `@sha256:...`, so what's in stage and prod is byte-identical to what was tested in dev.

**Q: How are secrets handled?**
A: Azure Key Vault, RBAC-mode, one vault per env. The CSI Secrets Store driver mounts secrets as files in pods. Pods authenticate via Workload Identity — a federated credential ties their K8s ServiceAccount to a UAMI that has `Key Vault Secrets User` on the right vault. No secrets in Git, no secrets in env vars (unless explicitly synced).

**Q: How does the cluster pull from ACR without an imagePullSecret?**
A: The AKS kubelet has a User-Assigned Managed Identity granted `AcrPull` on each ACR. Image pulls happen at kubelet level using that identity — no per-pod secret needed.

**Q: How does HTTPS work?**
A: NGINX Ingress Controller terminates TLS. cert-manager issues wildcard certs from Let's Encrypt using the DNS-01 challenge against my Azure DNS zone. external-dns auto-creates A records for hostnames declared on Ingress objects. The ingress gets a static Azure Public IP so DNS records survive cluster rebuilds.

**Q: How do you observe the system?**
A: kube-prometheus-stack provides Prometheus, Grafana, Alertmanager, node-exporter, kube-state-metrics. Default dashboards for cluster health, per-service RED metrics, and ingress latency. Azure Log Analytics ingests container logs via Container Insights.

**Q: How do you deal with prod outages?**
A: Rollback is `git revert` on the GitOps PR — ArgoCD self-heal returns the cluster to the previous state, and because images are pinned by digest the rollback is deterministic. Alerts go to Alertmanager (channel TBD: email/Slack/PagerDuty). Runbooks and ADRs are in `docs/`.

**Q: What does it cost?**
A: List price ~$500–700/mo at typical loads. Levers: switch user node pools to burstable VMs, scale dev to zero outside work hours, drop log retention. `az aks stop` pauses the cluster entirely.

**Q: How would you tear it down cleanly?**
A: Reverse-of-build order — apps → platform charts → namespaces → federated credentials → env stacks (`terraform destroy` on prod/stage/dev) → shared stack → bootstrap. Then purge soft-deleted Key Vaults, revert DNS delegation at the registrar, and clean up Azure DevOps service connections. Documented in `architecture-design.md` §20a.

---

## 9. The 90-second whiteboard version

If asked to draw it on a board, this is the order I'd sketch:

1. Box: **GitHub** (mono-repo).
2. Arrow → **Azure DevOps** (CI builds + Trivy scan).
3. Arrow → **ACR dev** (image push). Dotted arrow back to GitHub: "PR: bump digest."
4. Arrow → **ArgoCD** (watches GitOps folder).
5. Arrow → **AKS cluster** (single cluster, three namespaces).
6. Inside the cluster: **NGINX Ingress** ← end user. **cert-manager** ↔ Let's Encrypt + Azure DNS. **CSI Secrets Store** ← Key Vault. **Prometheus** scraping pods.
7. Side note: **Terraform** owns everything in Azure; state lives in an Azure Storage account.
8. Promotion arrow: **ADO** dashed → **ACR stage** dashed → **ACR prod** (`az acr import`).

If they ask "why three ACRs?" — say isolation and immutable-digest promotion. If they ask "why one cluster?" — say cost and ops, mitigated by per-env node pools and RBAC. If they ask "what would you change?" — service mesh, image signing, multi-region.

---

## 10. Reference links

- Detailed architecture: `architecture-design.md`
- Build & teardown phases + decisions: `cicd-pipeline-plan.md`
- Visual diagrams: `architecture-diagram.md` (and rendered SVG/PNG in `diagrams/`)
- Terraform module specifications: `terraform-modules.md`
