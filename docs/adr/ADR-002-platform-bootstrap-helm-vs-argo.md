# ADR-002: Platform bootstrap — Helm CLI vs Argo CD Applications

**Status:** Accepted (document current state; revisit if full GitOps for platform is required)  
**Date:** 2026-06-02  

## Context

Phase 2 installs **ingress-nginx**, **cert-manager**, **external-dns**, **kube-prometheus-stack**, and **Argo CD** with **`helm upgrade --install`**. After that, the Argo **root app** syncs `gitops/bootstrap/applications/` (workload apps, `gitops/platform/*` policies, ingress extras for Grafana/Argo).

`gitops/README.md` and older design docs sometimes implied every platform component is an Argo `Application` under `gitops/apps/platform/`. In the repo today, `apps/platform/` holds **Helm values files** consumed by the phase guide, not Argo app manifests.

## Decision

**Keep Helm-first platform install for v1.**

| Approach | Pros | Cons |
|----------|------|------|
| **Helm CLI (current)** | Matches many AKS tutorials; easy static IP wiring for ingress; fewer Argo cycles during first bootstrap; values still live in Git | Platform drift if someone runs Helm locally without committing value changes; two tools (Helm + Argo) |
| **Argo-only platform** | Single reconciliation path; cluster state fully from Git; easier drift detection | Chicken-and-egg (Argo must exist before Argo installs itself); harder first-time debug; ingress LB IP wiring needs careful chart ordering |
| **Hybrid (current + optional later)** | Ship now; migrate component-by-component to Argo when stable | Two paths during transition; docs must stay explicit |

We accept the **hybrid** reality: Helm installs the core platform; Argo owns app workloads and namespace policy manifests.

## Consequences

- Documentation and Medium posts must say **Helm first, then root app** (not “Argo installs ingress”).
- `ingress-nginx` will **not** appear as an Argo `Application` until someone adds `gitops/bootstrap/applications/platform-ingress.yaml` (or similar).
- `gitops/apps/platform/` remains the **source of truth for Helm values**, even when install is CLI-driven.

## If you want to move to Argo-managed platform later

Suggested order (each step is a PR + phase doc update):

1. **kube-prometheus-stack** — already has values in Git; low risk as Argo app in `monitoring` namespace (watch CRD/webhook ordering).
2. **cert-manager** — ClusterIssuer in Git; ensure CRDs install before issuers (sync waves).
3. **external-dns** — depends on Workload Identity setup; keep `azure.json` out of Git (use WI-only values).
4. **ingress-nginx** — coordinate static `loadBalancerIP` and Azure LB annotations with Terraform output (Helm parameters or Kustomize overlay).
5. **Argo CD self-management** — optional last step (`platform-argocd` already syncs ingress extras, not the Helm release).

**Do not** delete Helm paths from the phase guide until Argo paths are validated on a fresh cluster rebuild.

## Alternatives considered

- **Terraform Helm provider** for platform — couples apply time to cluster; harder to iterate than GitOps.
- **Flux instead of Argo** — out of scope; would replace CD layer entirely.

## References

- [phase-02-cluster-bootstrap.md](../implementation/phase-02-cluster-bootstrap.md)
- [gitops/README.md](../../gitops/README.md)
- [ARCHITECTURE.md](../../ARCHITECTURE.md)
