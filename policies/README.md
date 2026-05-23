# Kubernetes policy & networking

This folder is reserved for **policy bundles** (Kyverno, Gatekeeper, OPA) and any cluster-wide policy YAML you want to version outside GitOps paths (see [SECURITY.md](../SECURITY.md) and [Phase 8](../docs/implementation/phase-08-hardening.md)).

## Suggested layout (future)

- `network/` — optional copies or overlays if you split policy from `gitops/platform/`
- `kyverno/` or `opa/` — admission policy bundles if you adopt them

## Quick validation

```bash
kubectl get networkpolicy,resourcequota,limitrange -n dev
kubectl get ns dev stage prod --show-labels
```
