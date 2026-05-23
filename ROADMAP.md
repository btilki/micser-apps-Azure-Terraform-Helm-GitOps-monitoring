# Roadmap

Planned and out-of-scope work for **Online Boutique on Azure**. Current deployment: [DEPLOYMENT.md](DEPLOYMENT.md). Architecture: [ARCHITECTURE.md](ARCHITECTURE.md).

---

## Current (v1)

| Area | Status |
|------|--------|
| Terraform bootstrap, shared, dev/stage/prod | Implemented |
| AKS + ingress, cert-manager, external-dns, monitoring, Argo CD | Implemented (Phase 2) |
| Owned services: frontend, cart, currency, product catalog, redis-cart | Charts, GitOps, CI YAML in repo |
| Promote dev → stage → prod by digest | `pipelines/promote/` |
| Platform guardrails (NetworkPolicy, quota, PSS) | `gitops/platform/` |
| Runbooks (rollback, ingress, cert, Argo) | `docs/runbooks/` |
| Scaffold app images | `apps/*/Dockerfile` — replace with upstream source optional |

---

## Next

| Item | Notes |
|------|--------|
| Real microservices-demo source in `apps/` | Replace scaffold Dockerfiles; enable CI tests |
| Register all `pipelines/ci/*.yml` in Azure DevOps | Phase 5 |
| Alertmanager placeholders | `REPLACE_*` in kube-prometheus-stack values |
| Custom hostnames / DNS | Replace `*.boutique.example.com` in values |
| Rehearsed prod rollback | [prod-rollback](docs/runbooks/prod-rollback.md), [known-good digests](docs/gitops/prod-known-good-digests.md) |

---

## Later

| Item | Location (planned) |
|------|-------------------|
| Upstream boutique services (checkout, payment, …) | Argo apps + upstream images |
| ADRs (e.g. per-env ACR) | `docs/adr/` — extract from [architecture-design.md](docs/architecture-design.md) |
| Observability deep-dives | `docs/observability/` |
| Disaster recovery (RPO/RTO, rebuild) | `docs/disaster-recovery/` |
| Cost estimation and budgets | `docs/cost/` — bootstrap budget flag exists in Terraform |
| Kyverno / Gatekeeper admission policies | `policies/` or GitOps |
| Optional dedicated node pools per env | Taints/tolerations in Helm values |
| CI on every commit | Re-enable `trigger` in `pipelines/ci/*.yml` |

---

## Non-goals

- Multi-region active-active
- Service mesh (Istio/Linkerd) in v1
- Compliance certifications (SOC2, etc.)
- Hosting non-demo workloads on the same cluster

---

## Historical build order

Phases 0–10 in `docs/implementation/` document how the platform was assembled. New deployments should follow [DEPLOYMENT.md](DEPLOYMENT.md), not treat phase numbers as future milestones.
