# Helm charts

One chart per owned microservice under `charts/<service>/`, plus shared helpers under `_common/` (optional). Workload list: [ARCHITECTURE.md — Application scope](../ARCHITECTURE.md#application-scope-v1).

Image references use GitOps registry + **digest** per environment. Only `frontend` needs an `Ingress` in the default design.
