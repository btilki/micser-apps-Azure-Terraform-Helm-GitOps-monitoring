# Kubernetes policy & networking

Add **NetworkPolicies**, **PodDisruptionBudgets**, and optional **Kyverno / Gatekeeper** policies here (see `docs/architecture-design.md` §8, §13, Phase 8 in `docs/implementation/`).

Suggested layout:

- `network/` — NetworkPolicy YAML per namespace or service
- `kyverno/` or `opa/` — policy bundles if you adopt them
