# Tools and Workflow Overview

This file explains the main tools in this project, how they connect, and the delivery flow from code to production.

**v1 application scope:** This repo builds and promotes **five owned workloads** (four microservices + **Redis** as `redis-cart`) via CI and ACR. **`checkoutservice`, `emailservice`, `paymentservice`, `shippingservice`, `recommendationservice`**, and **`loadgenerator`** are expected to run from **upstream Google microservices-demo images** when you need the full demo path; **`adservice`** is optional in v1. See `docs/cicd-pipeline-plan.md` (v1 scope) and `docs/architecture-design.md`.

## 1) Tools used in this project

- **Terraform**: creates Azure infrastructure (state storage, AKS, networking, DNS, ACR, Key Vault).
- **Azure Kubernetes Service (AKS)**: runs platform and microservice workloads.
- **Helm**: packages Kubernetes manifests for each service (`charts/`).
- **Argo CD**: applies GitOps manifests from this repository to AKS.
- **Azure Container Registry (ACR)**: stores service images per environment (`dev`, `stage`, `prod`).
- **Azure DevOps Pipelines**: builds/scans images and runs promotion pipelines.
- **Kubernetes + kubectl**: operational control plane for deployments, ingress, certs, and debugging.
- **cert-manager**: issues TLS certificates for ingress hosts.
- **ingress-nginx**: exposes services via HTTP/HTTPS.
- **external-dns**: manages DNS records based on ingress/service state.
- **kube-prometheus-stack (Prometheus/Grafana/Alertmanager)**: metrics, dashboards, and alerting.
- **GitHub (or Azure Repos) + PR policies**: change control and approvals.

## 2) How tools relate to each other

1. **Terraform** provisions cloud resources used by all runtime tools (AKS, ACR, DNS, identities).
2. **CI pipelines** build images and push to **dev ACR**.
3. CI updates GitOps values (image digest), opens PR, and after merge:
4. **Argo CD** detects Git changes and deploys to AKS using **Helm charts** + env values.
5. **Promotion pipelines** copy tested images across ACRs (`dev -> stage -> prod`) by digest.
6. Promotion pipeline updates target environment GitOps values and opens PR.
7. After PR merge, Argo deploys target environment; in prod, sync is manual.
8. **Ingress + cert-manager + external-dns** provide public HTTPS endpoints.
9. **Prometheus/Grafana/Alertmanager** monitor runtime and trigger operational alerts.

## 3) End-to-end delivery steps

1. Developer commits code and opens PR.
2. CI builds/tests/scans image, pushes to dev ACR.
3. CI opens GitOps PR with new digest in `gitops/envs/dev/`.
4. Merge PR -> Argo deploys to `dev`.
5. Run stage promotion pipeline -> merge stage GitOps PR -> Argo deploys to `stage`.
6. Validate stage (functional checks + dashboards).
7. Run prod promotion pipeline with approval -> merge prod PR.
8. Operator performs manual sync in Argo for prod.
9. Validate prod endpoints/health and monitor alerts.
10. If needed, rollback by reverting/pinning digest via GitOps PR and re-syncing.

## 4) Repository map (where each tool is configured)

- `infra/terraform/` -> Terraform infrastructure code
- `charts/` -> Helm charts
- `gitops/apps/` -> Argo CD Application manifests
- `gitops/envs/` -> environment-specific Helm values (image digests, sizing, ingress hosts)
- `gitops/platform/` -> platform-level Kubernetes manifests
- `pipelines/ci/` -> service CI pipelines
- `pipelines/promote/` -> promotion pipelines
- `pipelines/templates/` -> reusable pipeline logic
- `docs/runbooks/` -> incident response and operations procedures

## 5) Operational rule of thumb

- **Build once, promote by digest, deploy via GitOps, verify with monitoring, rollback via Git PR.**
