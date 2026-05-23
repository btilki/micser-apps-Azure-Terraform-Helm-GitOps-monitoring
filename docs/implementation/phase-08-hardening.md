# Phase 8 — Hardening

[← Phase 7](phase-07-prod-environment.md) · [Deployment](../../DEPLOYMENT.md) · [Phase 9 →](phase-09-polish.md)

**Goal:** Confirm operational and security guardrails are active across runtime, CI, and cost — most YAML already lives in Git; you validate and tune.

## Why hardening is a separate phase

Dev/stage/prod need **predictable blast radius**: default-deny networking, pod security levels, resource caps, vulnerability gates on images, and spend alerts. Applying everything at once before apps run causes friction; this phase verifies controls after workloads are stable.

## This repository (already present)

| Control | Location |
|---------|----------|
| Pod Security labels (`baseline` dev, `restricted` stage/prod) | `gitops/platform/{dev,stage,prod}/namespace.yaml` |
| Default-deny + baseline ingress + core egress NetworkPolicies | `gitops/platform/{dev,stage,prod}/networkpolicy-*.yaml` |
| ResourceQuota / LimitRange | `gitops/platform/{dev,stage,prod}/resourcequota.yaml`, `limitrange.yaml` |
| Helm `securityContext` defaults | `charts/*/values.yaml`, deployment templates |
| CI Trivy gate (HIGH+CRITICAL fail build) | `pipelines/ci/*.yml` |
| Optional subscription budget (80% notification) | `infra/terraform/envs/bootstrap/` (`enable_subscription_budget`, `budget_notification_emails`) |
| Policy folder index | [policies/README.md](../../policies/README.md) |

Argo CD Applications **`platform-dev`**, **`platform-stage`**, **`platform-prod`** sync the `gitops/platform/<env>/` trees. You normally **edit and PR** those files rather than creating parallel copies under `policies/`.

## Step-by-step

### Prerequisites

```bash
kubectl get applications -n argocd
kubectl get pods -n stage,prod
```

### 1) Validate GitOps platform policies

After any policy PR merges, confirm objects exist:

```bash
kubectl get networkpolicy,resourcequota,limitrange -n dev
kubectl get networkpolicy,resourcequota,limitrange -n stage
kubectl get networkpolicy,resourcequota,limitrange -n prod
kubectl get ns dev stage prod --show-labels
```

If a service cannot reach a dependency, adjust **egress** NetworkPolicies in `gitops/platform/<env>/networkpolicy-egress-core.yaml` (or service-specific policies) and re-sync **`platform-*`**.

**Rollout order for changes:** `dev` → `stage` → `prod` (separate PRs recommended).

### 2) CI vulnerability gate

Trivy runs in each `pipelines/ci/<service>.yml`. Trigger a pipeline on a known-good image and confirm success; optionally test failure policy on a deliberate vulnerable base tag in a throwaway branch.

### 3) Azure budget alerts

In `infra/terraform/envs/bootstrap/terraform.tfvars`, set `enable_subscription_budget = true` and `budget_notification_emails`, then:

```bash
cd infra/terraform/envs/bootstrap
terraform plan
terraform apply
```

Confirm notification routing in Azure Portal (**Cost Management → Budgets**).

### 4) Application traffic smoke

With owned services running in dev:

```bash
kubectl get pods -n dev
# Exercise storefront; watch for NetworkPolicy drops in workload logs if paths fail
```

## Done checklist

- [ ] NetworkPolicies, quotas, and limit ranges present in **dev**, **stage**, and **prod**.
- [ ] Namespace Pod Security labels match design (baseline / restricted).
- [ ] CI fails on HIGH/CRITICAL Trivy findings for service pipelines you use.
- [ ] Budget notification configured (if using bootstrap budget feature).

---

[← Phase 7](phase-07-prod-environment.md) · [Deployment](../../DEPLOYMENT.md) · [Phase 9 →](phase-09-polish.md)
