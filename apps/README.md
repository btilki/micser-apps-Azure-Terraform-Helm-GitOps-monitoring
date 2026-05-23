# Application source (Online Boutique)

Docker build contexts for **owned v1 services**. CI builds from `apps/<service>/Dockerfile` and pushes to the **dev** ACR (see `pipelines/ci/*.yml`).

## Current state in this repo

| Service | Dockerfile | Notes |
|---------|------------|--------|
| `frontend` | `apps/frontend/Dockerfile` | Scaffold nginx page until real UI source is added |
| `cartservice` | `apps/cartservice/Dockerfile` | Scaffold; extend with microservices-demo source |
| `currencyservice` | `apps/currencyservice/Dockerfile` | Scaffold |
| `productcatalogservice` | `apps/productcatalogservice/Dockerfile` | Scaffold |
| `redis-cart` | `apps/redis-cart/Dockerfile` | Scaffold |

Charts, GitOps Applications, and Azure DevOps pipelines for all five services **already exist** — see [Phase 5](../docs/implementation/phase-05-fan-out-services.md). You do not need new folder scaffolding to deploy; run CI after registering pipelines.

## Optional — add real microservices-demo source

Expected upstream services for a **full** boutique demo (not all built by this repo’s CI):  
`checkoutservice`, `emailservice`, `paymentservice`, `shippingservice`, `recommendationservice`, `loadgenerator`, optional `adservice`.

**Example — git subtree (from repo root):**

```bash
git remote add microservices-demo https://github.com/GoogleCloudPlatform/microservices-demo.git
git fetch microservices-demo
git subtree add --prefix=apps/microservices-demo microservices-demo main --squash
```

Then copy or point each `apps/<service>/Dockerfile` at the upstream service directory and update CI lint/test steps in `pipelines/ci/<service>.yml`.
