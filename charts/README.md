# Helm charts

One chart per microservice under `charts/<service>/`, plus shared helpers under `_common/` (optional).

**v1 owned charts (Phase 5):** `frontend`, `redis-cart`, `productcatalogservice`, `currencyservice`, `cartservice`.

- Image references should follow GitOps: registry + **digest** per environment (see [ARCHITECTURE.md](../ARCHITECTURE.md)).
- Only `frontend` needs an `Ingress` in the default design.
