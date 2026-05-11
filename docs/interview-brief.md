# Project Walkthrough — Interview Brief

A short, interview-friendly explanation of the project. Read this end-to-end in ~5 minutes; use the Q&A at the bottom for likely follow-up questions.

> **Project:** End-to-end CI/CD platform for a microservices application on Azure.
> **Application:** Google's *Online Boutique* — 11 polyglot services + Redis. v1 owns 6 in-tree (frontend, cartservice, productcatalogservice, currencyservice, redis-cart, plus a custom `backend`); the remaining 5 services + loadgen run from upstream Google images via overlay-only Helm values.
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

## 4. The tool stack — what each does and why

Each tool gets a short *what + why* explanation. Group them in your head: *Source & CI/CD · Containers & cluster networking · Identity & secrets · Networking & TLS · IaC & observability · Cluster guardrails*.

### Source & development

- **GitHub** — mono-repo for app code, Helm charts, GitOps manifests, and Terraform. Single source of truth simplifies cross-cutting refactors; CODEOWNERS and path-scoped pipelines limit blast radius.
- **Cursor IDE** — local development environment.

### CI/CD

- **Azure DevOps** — runs build pipelines and the cross-registry promotion pipeline. Native to the Azure ecosystem (service connections, AAD auth, Key Vault tasks).
- **Trivy** — open-source vulnerability scanner from Aqua Security. Runs after `docker build` and before `docker push`, comparing image layers against the public CVE database and **failing the pipeline on any HIGH/CRITICAL CVE**. Insecure images never reach the registry — security shifts left into the developer's PR.
- **ArgoCD** — in-cluster GitOps controller that keeps live cluster state matching what's declared in Git. We use the **app-of-apps pattern** (one root Application referencing per-service Applications) and per-env `AppProject` scoping. Sync flags: *auto-sync* (poll Git and apply, used in dev), *auto-prune* (delete from cluster when removed from Git), *self-heal* (revert manual `kubectl edit` back to Git's state).

### Containers & cluster networking

- **Docker** — builds container images in CI.
- **Azure Container Registry (ACR)** — three env-scoped registries (dev/stage/prod). Hard isolation between environments, with `az acr import` of immutable digests for promotion.
- **Azure Kubernetes Service (AKS)** — managed Kubernetes runtime with a free control plane, native AAD integration, and first-party Workload Identity.
- **Helm** — package and templating for K8s manifests, one chart per microservice.
- **Azure CNI Overlay (the AKS networking plugin)** — assigns pod IPs from a virtual cluster-internal range (`10.244.0.0/16`) instead of consuming IPs from the underlying VNet. Avoids the IP-exhaustion problem of legacy Azure CNI; trade-off is a small encapsulation overhead on cross-node pod traffic. Matters here because our VNet is only `10.20.0.0/22` (~1024 addresses) but pods scale independently.
- **Azure VNet + NSG** — VNet is the private layer-3 network in Azure (subnets for AKS nodes, private endpoints, optional bastion); NSG is a stateful layer-4 firewall on the subnet/NIC. We default-deny on the AKS subnet and allow only Azure control plane traffic, the configured private endpoints, and a controlled internet egress.

### Identity & secrets

- **AAD-integrated AKS** — the cluster uses Azure AD (Entra ID) as its OIDC identity provider for the Kubernetes API server. `kubectl` users authenticate via AAD (with MFA/conditional access), and Kubernetes RBAC binds AAD group object IDs to namespace-scoped Roles. No long-lived kubeconfigs to leak.
- **Azure AD (Entra ID)** — Microsoft's identity platform; the single source of truth for who can run kubectl, who signs into Grafana, and who approves a prod GitOps PR. Group membership changes propagate automatically into K8s permissions.
- **User-Assigned Managed Identities (UAMIs)** — Azure identity objects with their own object IDs and lifecycle, separate from any user, that survive cluster recreation. We use one UAMI per environment, one each for cert-manager and external-dns, and one for the AKS kubelet (which holds `AcrPull` on every ACR).
- **Workload Identity (federated credentials)** — bridges K8s ServiceAccounts → UAMIs via OIDC, so pods authenticate to Azure with **zero static credentials** in the cluster. Mechanism: AKS exposes an OIDC issuer Azure trusts; a *federated credential* on a UAMI declares "I trust this issuer + this subject (`system:serviceaccount:<ns>:<sa>`)"; the pod presents a projected SA token and Azure issues the UAMI's access token in return.
- **Azure Key Vault** — env-scoped secret storage in **RBAC mode** (Azure RBAC role assignments instead of legacy access policies, so it integrates with PIM and audit logs), reachable only via **private endpoint** (public endpoint disabled), with **purge protection** in prod (90-day soft-delete window cannot be bypassed). Three vaults total — one per environment.
- **CSI Secrets Store driver + Azure provider** — a Kubernetes CSI driver that mounts Key Vault secrets as files into the pod's filesystem (e.g. `/mnt/secrets-store/`). Pods authenticate via Workload Identity; optional `syncSecret: true` mirrors a fetched secret as a native K8s `Secret` for charts requiring `valueFrom: secretKeyRef`. No client SDK or credentials needed inside the app.
- **Private endpoints for ACR and Key Vault** — a private endpoint is a NIC inside our VNet that maps to a specific PaaS resource. Combined with `public_network_access_enabled = false`, image pulls and secret reads stay on Azure's backbone via private DNS (`privatelink.azurecr.io`, `privatelink.vaultcore.azure.net`) and never touch the public internet.

### Networking & TLS

- **NGINX Ingress Controller** — the L7 reverse-proxy pod fronting the cluster. K8s `Ingress` objects declare host→service routing; NGINX implements it, terminates TLS, and forces HTTP→HTTPS redirect. It owns one `LoadBalancer` Service bound to a static Azure Public IP (created in Terraform), so DNS records survive cluster rebuilds.
- **cert-manager** — Kubernetes controller that automates the TLS cert lifecycle: requests a cert from Let's Encrypt, completes the validation challenge, stores the cert as a K8s `Secret`, and renews ~30 days before expiry.
- **DNS-01 challenge against Azure DNS** — ACME requires you to prove domain control before issuing a cert; DNS-01 places a token in a DNS TXT record. We use it instead of HTTP-01 because it's the only option that supports **wildcard certs** (`*.boutique.biroltilki.art`) and works even before the ingress is publicly reachable. cert-manager's Azure DNS plugin authenticates via Workload Identity and writes the TXT record into the `biroltilki.art` zone.
- **Let's Encrypt** — free, automated, public ACME CA. Issues 90-day certs (forces healthy renewal hygiene). We iterate on issuer config against `letsencrypt-staging` first, then switch to `letsencrypt-prod`.
- **external-dns** — auto-creates A records in Azure DNS based on hostnames declared on Ingress objects, so DNS stays in lockstep with the cluster.
- **Azure DNS** — public zone for `biroltilki.art`.

### IaC & observability

- **Terraform** — provisions all Azure resources; modules per service, env stacks per environment.
- **Azure Storage** — remote Terraform state (versioned, soft-deleted).
- **Prometheus + Alertmanager** — metrics scraping and alert routing.
- **Grafana** — dashboards (cluster health, per-service RED metrics, ingress latency).
- **Azure Log Analytics** — container logs and AKS control-plane diagnostics, ingested via the Container Insights add-on.

### Cluster guardrails

- **Pod Security Standards (PSS)** — built-in K8s admission policy with three levels (`privileged`, `baseline`, `restricted`), enforced by labeling a namespace. Plan: `baseline` in dev, `restricted` in stage/prod. *Status: namespace labels pending.*
- **NetworkPolicies** — K8s-native firewall rules for pod-to-pod traffic. K8s defaults to allow-all; we run default-deny and explicitly allow required paths (e.g. "frontend → checkoutservice on 5050"). Requires a CNI that supports them — we use Calico. *Status: prod baseline shipped (`gitops/platform/prod/networkpolicy-baseline.yaml`); stage/dev pending.*
- **ResourceQuotas + LimitRange** — per-namespace caps on aggregate CPU/memory/pod count, plus per-container defaults and maxes. Prevents one runaway pod from starving the cluster. *Status: shipped in stage/prod.*

---

## 5. How a code change reaches a user (end-to-end)

1. **Developer pushes** a change to GitHub.
2. **Azure DevOps CI** triggers: lints, tests, builds the container image, runs **Trivy**, pushes the image to **ACR dev**, then opens a PR bumping the image digest in `gitops/envs/dev/`.
3. **ArgoCD** notices the GitOps change and **syncs** the dev namespace — auto-sync, auto-prune, self-heal.
4. **Promotion to stage** is a separate pipeline: `az acr import` copies the **same digest** from ACR dev to ACR stage, then opens a PR in `gitops/envs/stage/`. After approval, ArgoCD syncs stage.
5. **Promotion to prod** repeats the same shape; prod requires manual ArgoCD sync after PR approval.
6. **Inside the cluster**, when ArgoCD applies the new Deployment manifest:
   1. **Image pull.** Each node's kubelet pulls the new image from the env-specific ACR. It authenticates with the kubelet UAMI's `AcrPull` role; image bytes flow over the ACR private endpoint, never the public internet.
   2. **Pod startup with Workload Identity.** The pod's ServiceAccount is annotated with the env's UAMI client ID. Kubelet mounts a projected SA token into the pod.
   3. **Secret mounting.** The CSI Secrets Store volume initializes: the driver authenticates to Key Vault using the projected SA token federated to the UAMI, fetches the configured secrets, and writes them as files into `/mnt/secrets-store/`. The application reads them like any other file.
   4. **Service-to-service traffic.** Microservices call each other by `ClusterIP` Service names; CoreDNS resolves names to pod IPs; NetworkPolicies (in prod) gate which paths are allowed.
7. **The end user opens the URL.** DNS resolves `boutique.biroltilki.art` via the registrar → Azure DNS → A record (created earlier by external-dns from the Ingress hostname) → static Azure Public IP. Traffic hits the Azure Load Balancer in front of the cluster, lands on the NGINX ingress pod. NGINX terminates TLS using the wildcard cert (managed by cert-manager, auto-renewed via Let's Encrypt's DNS-01 challenge), inspects the Host header, and routes to the `frontend` Service. Frontend orchestrates the gRPC call chain across the microservices and returns. **Prometheus scrapes** every pod's `/metrics` continuously; **Alertmanager** routes alerts; container logs ship via the AKS Container Insights add-on into Azure Log Analytics.

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
