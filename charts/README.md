# Helm charts

One chart per microservice under `charts/<service>/`, plus shared helpers under `_common/` (optional).

- Image references should follow GitOps: registry + **digest** per environment (`docs/architecture-design.md` §8).
- Only `frontend` needs an `Ingress` in the default design.
