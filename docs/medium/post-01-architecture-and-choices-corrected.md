# Running Google's Online Boutique on Azure with AKS, GitOps, and Digest Promotion

**Subtitle:** Part 1 of 3 — Why one AKS cluster, three registries, and Argo CD beat "kubectl apply" for a realistic platform engineering demo

**Repository:** https://github.com/btilki/micser-apps-Azure-Terraform-Helm-GitOps-monitoring

**Images to insert (from repo `docs/diagrams/`):**
1. `00-platform-overview.png` — after "The big picture"
2. `02-azure-resources.png` — in Azure foundation section
3. `01-cicd-flow.png` — after three ACRs section
4. `03-inside-cluster.png` — in cluster layout section

---

*Part 1 of 3. In Part 2 we'll deploy the platform and get the first service live on HTTPS in dev. In Part 3 we'll promote releases through stage and prod and cover operations.*

---

I wanted a project that felt like real platform engineering—not a single `docker run`, not a slide deck of boxes, and not a cluster where "production" means changing a tag by hand. So I built an end-to-end platform for [Google's Online Boutique microservices demo](https://github.com/GoogleCloudPlatform/microservices-demo) on Azure: Infrastructure is defined as code. CI builds images once. GitOps deploys immutable digests. And dev, stage, and prod stay logically isolated—even while sharing a single AKS cluster.

Everything is open source. If you want to follow along later, the repository is here:

**https://github.com/btilki/micser-apps-Azure-Terraform-Helm-GitOps-monitoring**

This first article is about *why* the system is shaped the way it is. The commands come in Part 2.

---

## What I was optimizing for

Online Boutique is a familiar demo: many small services, one public web UI, everything else internal. That's a good stand-in for teams learning Azure Kubernetes Service (AKS), Helm, and delivery pipelines.

I set a few non-negotiable goals:

**Reproducible infrastructure.** Networks, the cluster, DNS, registries, and Key Vaults are Terraform modules with remote state—not click-ops you can't replay.

**Build once, promote the same artifact.** When something reaches stage or prod, it should be the *same image manifest* that passed dev, not a rebuild that might differ because of cache, dependencies, or time.

**Git as the deployment contract.** The cluster should reconcile from Git (Argo CD), not from "whoever ran helm last." Production changes should need review—and in prod, a human should still choose when to sync.

**HTTPS and observability by default.** Public hostnames, automatic DNS and certificates, and Prometheus/Grafana/Alertmanager so you're not flying blind after the first deploy.

**Isolation without three clusters.** Dev, stage, and prod are separate *logical* environments (namespaces, policies, registries). For learning and portfolio projects, a single well-isolated cluster is often more operationally realistic than maintaining three underutilized clusters.

What I explicitly did *not* try to solve: multi-region active-active, a service mesh, or compliance certifications. This is a strong engineering demo, not a regulated production landing zone.

---

## The big picture

At a high level, work flows like this:

A developer pushes application or GitOps changes to GitHub. Azure DevOps builds container images for the services this repo owns, scans them, and pushes to a **development** Azure Container Registry (ACR). The pipeline opens a pull request that bumps an **immutable digest** in GitOps values—not a floating `:latest` tag.

To move toward stage or prod, a **promotion** pipeline runs `az acr import` to copy that digest into the target environment's registry, updates the right values file, and opens another PR. After merge, Argo CD applies Helm charts to the cluster. For production, sync is **manual**: merging Git is necessary but not sufficient to roll out.

[INSERT IMAGE: 00-platform-overview.png — Caption: End-to-end flow from developer to AKS via GitHub, Azure DevOps, ACRs, and Argo CD.]

That separation—**CI produces artifacts**, **promotion moves artifacts**, **GitOps declares desired state**, **Argo CD reconciles**—is the spine of the design. If you remember one thing from this post, remember that spine.

- CI produces artifacts.
- Promotion moves artifacts.
- GitOps declares desired state.
- Argo CD reconciles.

---

## Azure foundation: shared cluster, separate env resources

Terraform is split into layers on purpose:

**Bootstrap** creates remote state storage (once per subscription setup).

**Shared** delivers the long-lived platform: virtual network, Log Analytics, a public DNS zone, a single AKS cluster (`aks-boutique-weu` in the reference layout), and a stable public IP for ingress.

**Per environment** (`dev`, `stage`, `prod`) provisions its own resource group, **its own ACR**, Key Vault, and supporting pieces—so blast radius and permissions can follow environment boundaries even though the kube-apiserver is shared.

[INSERT IMAGE: 02-azure-resources.png — Caption: Terraform layers—bootstrap state, shared platform, per-environment registries and vaults.]

### Why three container registries?

An earlier design used one registry and promoted images by retagging. That's simple on paper and messy in practice: tags are mutable, audit trails get fuzzy, and it's too easy for prod to point at an image that was never validated in dev.

This project uses **one ACR per environment**—for example `acrboutiquedevweu`, `acrboutiquestageweu`, and `acrboutiqueprodweu`. Promotion runs:

```
az acr import  →  copy manifest by digest  →  update GitOps  →  Argo CD deploys
```

That removes an entire class of "works in dev, different in prod" deployment problems. The digest in `gitops/envs/prod/values-frontend.yaml` (and sibling files) is the contract.

```yaml
image:
  repository: acrboutiqueprodweu.azurecr.io/frontend
  digest: "sha256:..."
```

[INSERT IMAGE: 01-cicd-flow.png — Caption: CI builds to dev ACR; promotion imports digest to stage/prod; GitOps PRs record the change.]

---

## Inside the cluster

There is one AKS cluster. Workloads for the boutique app run in namespaces **dev**, **stage**, and **prod**. Platform components live in their own namespaces: `ingress-nginx`, `cert-manager`, `external-dns`, `monitoring`, and `argocd`.

[INSERT IMAGE: 03-inside-cluster.png — Caption: Platform namespaces and app namespaces on a single cluster.]

Isolation is layered—not perfect multi-tenant separation, but deliberate:

- **Namespaces and Argo CD AppProjects** scope what each environment's Applications may target.
- **ResourceQuota and LimitRange** cap consumption per namespace.
- **NetworkPolicies** default-deny and allow only the traffic paths the demo needs.
- **Pod Security** labels: baseline in dev, restricted in stage and prod.
- **Separate ACR per env** plus digest-pinned values so prod pulls from the prod registry.

Ingress is HTTPS-only: NGINX Ingress terminates TLS; cert-manager obtains certificates via **DNS-01** against Azure DNS; external-dns keeps records aligned with Ingress hosts. In the reference configuration, storefront URLs look like `dev.boutique.example.com`, `stage.boutique.example.com`, and `boutique.example.com`—you'll use your own zone when you deploy.

Only the **frontend** typically gets a public Ingress. The other owned services (`cartservice`, `currencyservice`, `productcatalogservice`, `redis-cart`) stay `ClusterIP`—which matches how the upstream demo is meant to be consumed.

---

## What this repository actually ships (v1)

To keep the first delivery tractable, the repo **builds and promotes five owned workloads**: frontend, cart, currency, product catalog, and Redis (`redis-cart`). Each has a Helm chart under `charts/`, environment values under `gitops/envs/`, and a CI pipeline under `pipelines/ci/`.

The remaining Online Boutique services can later be consumed directly from upstream Google images without rebuilding them in this repo.

That split matters for reading the architecture: the *platform* is complete; the *demo app surface area* is intentionally incremental.

---

## CI/CD and GitOps in one paragraph each

**Continuous integration (Azure DevOps)**

Pipelines build from each service's Dockerfile under `apps/` (for example `apps/frontend/Dockerfile`), run Trivy (fail on high/critical findings), push to the dev registry, and open a GitHub PR that updates `image.digest` in the dev values file. Triggers are off by default—you run pipelines manually while learning, then enable branch triggers when you're ready.

**Promotion (Azure DevOps)**

Separate pipelines import an approved digest from dev→stage or stage→prod, with a permission check on the service principal *before* import. Stage and prod GitOps PRs are the audit trail.

**Continuous delivery (Argo CD)**

An app-of-apps root syncs bootstrap Applications; child apps point at Helm charts plus per-env value files. Dev and stage may auto-sync; prod does not—operators sync prod apps explicitly after review.

The repository layout mirrors that mental model: `infra/terraform/` for Azure, `pipelines/` for automation, `gitops/` for desired state, `charts/` for packaging.

---

## Security and identity (overview)

Identity is easy to get wrong when three tools overlap. This design uses:

- **Azure RBAC** for registries, DNS, Key Vault, and pipeline service principals.
- **Kubernetes RBAC** (and optional Azure AD group bindings) for human `kubectl` access.
- **Git + Argo CD** for prod change control—CODEOWNERS, branch protection, manual prod sync.

Platform controllers (cert-manager, external-dns) use **Workload Identity**—federated managed identities, no long-lived secrets in manifests. Application secrets are intended for **Key Vault** and the Secrets Store CSI driver, not for Git.

I wrote a longer breakdown in the repo's `SECURITY.md`; Part 3 will touch promotion and prod gates in practice.

---

## Observability

The cluster runs **kube-prometheus-stack**: Prometheus scrapes metrics, Grafana dashboards visualize health, and Alertmanager routes alerts (ingress 5xx bursts, crash loops, certificate expiry) once you configure receivers. That's not glamorous architecture, but it's what makes the demo survivable after day one.

---

## What's in the repo vs what this post covers

| You'll find in GitHub | Covered here (Part 1) | Coming later |
|----------------------|------------------------|--------------|
| Terraform modules and env stacks | Why layers and three ACRs | Part 2: apply order and bootstrap |
| Phase-by-phase deployment guide | — | Part 2: through first HTTPS dev URL |
| Pipeline YAML and promote templates | CI vs promote vs GitOps roles | Part 2–3: register and run pipelines |
| Runbooks (rollback, ingress 5xx, certs) | — | Part 3: stage/prod and operations |

---

## Closing thoughts

The interesting part of this project isn't "Kubernetes on Azure"—it's tying together **immutable promotion**, **GitOps**, and **environment isolation** in a way you can explain on a whiteboard and reproduce from a clone.

If that matches what you're trying to learn, clone the repo, skim `ARCHITECTURE.md` and `DEPLOYMENT.md`, and watch for Part 2 next week—I'll walk through Terraform, cluster bootstrap, and the first Azure DevOps pipeline until the dev storefront answers on HTTPS.

**Repository:** https://github.com/btilki/micser-apps-Azure-Terraform-Helm-GitOps-monitoring

Questions and corrections are welcome in the repo issues; I'd rather fix the docs than let drift accumulate.

---

*Part 2 preview: bootstrap remote state, install ingress/cert-manager/external-dns/monitoring/Argo CD, register `pipelines/ci/frontend.yml`, merge the digest PR, and validate TLS on dev.*
