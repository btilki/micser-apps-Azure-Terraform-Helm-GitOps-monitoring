# Implementation phases

One file per phase. Follow phases in order and treat each file as an execution checklist.
Background and ADRs: [architecture-design.md](../architecture-design.md).

| Phase | Guide |
|-------|-------|
| 0 | [Repo scaffolding](phase-00-repo-scaffolding.md) |
| 1 | [Terraform foundation](phase-01-terraform-foundation.md) |
| 2 | [Cluster bootstrap](phase-02-cluster-bootstrap.md) |
| 3 | [First service — frontend](phase-03-first-service-frontend.md) |
| 4 | [Promotion pipeline](phase-04-promotion-pipeline.md) |
| 5 | [Fan-out remaining services](phase-05-fan-out-services.md) |
| 6 | [Stage environment](phase-06-stage-environment.md) |
| 7 | [Prod environment](phase-07-prod-environment.md) |
| 8 | [Hardening](phase-08-hardening.md) |
| 9 | [Polish](phase-09-polish.md) |
| 10 | [Destroy infrastructure](phase-10-destroy-infrastructure.md) |

## How to use these guides

1. Complete phases in build order: **0 -> 1 -> 2 -> ... -> 9**.
2. For each phase, execute steps in order and do not skip validation steps.
3. Open a PR at the end of each meaningful change set (infra, GitOps, pipeline).
4. Teardown is optional: run **phase 10** only when you want to remove Azure resources.

## Platform responsibilities (quick map)

- `GitHub`: source control, PR reviews, branch protection, CODEOWNERS, GitOps values updates.
- `Azure`: subscription/resource groups, ACR, AKS, DNS, identity/permissions.
- `Azure DevOps`: CI and promotion pipelines, service connections, environment approvals/checks.
- `Argo CD`: deploys from GitOps repository state after PR merge.
