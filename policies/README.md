# Kubernetes policy & networking

This folder is reserved for **policy bundles** (Kyverno, Gatekeeper, OPA) and any cluster-wide policy YAML you want to version outside GitOps paths (see `docs/architecture-design.md` and Phase 8 in `docs/implementation/`).

## What ships today (Phase 8)

Canonical runtime guardrails live next to the Argo CD `platform-*` apps:

| Control | Location |
| -------- | -------- |
| Pod Security labels (`baseline` dev, `restricted` stage/prod) | `gitops/platform/{dev,stage,prod}/namespace.yaml` |
| Default-deny + baseline ingress + core egress NetworkPolicies | `gitops/platform/{dev,stage,prod}/networkpolicy-*.yaml` |
| ResourceQuota / LimitRange | `gitops/platform/{dev,stage,prod}/resourcequota.yaml`, `limitrange.yaml` |
| Helm `securityContext` defaults | `charts/*/values.yaml` and `charts/*/templates/deployment.yaml` |
| CI image scan gate (Trivy HIGH+CRITICAL, fail build) | `pipelines/ci/*.yml` |
| Optional subscription budget (80% actual notification) | `infra/terraform/envs/bootstrap/` (`enable_subscription_budget`, `budget_notification_emails`) |

## Suggested layout (future)

- `network/` — optional copies or overlays if you split policy from `gitops/platform/`
- `kyverno/` or `opa/` — admission policy bundles if you adopt them

## Quick validation

```bash
kubectl get networkpolicy,resourcequota,limitrange -n dev
kubectl get ns dev stage prod --show-labels
```
