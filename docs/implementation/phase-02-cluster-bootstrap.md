# Phase 2 — Cluster bootstrap

[← Phase 1](phase-01-terraform-foundation.md) · [Index](README.md) · [Phase 3 →](phase-03-first-service-frontend.md)

**Goal:** Ingress, TLS stack, DNS sync, metrics, Argo CD running; cluster ready for GitOps.

---

## Implementation

> **Use:** Terminal (`kubectl`, `helm`), **Helm** repos, optional **Terraform** if you install platform via code, **Azure Portal** (managed identities, DNS zone IAM), **Argo CD UI** or CLI after install.

1. **CSI Secrets Store** — Install driver + Azure provider if not using an AKS add-on that already provides it. Confirm OIDC / Workload Identity on the cluster matches your Terraform (`kubectl` / Azure Portal).

2. **NGINX Ingress** — Install to `ingress-nginx`. Set the Service `LoadBalancer` to use the **static public IP** from Phase 1 (Helm values: Azure annotations for PIP name / IP — check current NGINX Ingress + AKS docs).

3. **cert-manager** — Install to `cert-manager`. Apply `ClusterIssuer` manifests for Let’s Encrypt **DNS-01** against your Azure DNS zone (identity needs permission to create TXT records).

4. **external-dns** — Install to `external-dns`. Grant the workload identity **DNS Zone Contributor** on the public zone (or equivalent for your setup).

5. **kube-prometheus-stack** — Install to `monitoring`. Ensure a default **StorageClass** exists for Prometheus PVC or adjust values.

6. **Argo CD** — Install to `argocd`. Initial admin: `argocd admin initial-password -n argocd` (or use your chart’s flow). Expose via **Ingress + cert** (e.g. `argocd.<your-domain>`) or temporarily `kubectl port-forward svc/argocd-server -n argocd 8080:443`.

7. **Repo credential in Argo CD** — **Settings → Repositories**: add SSH key, HTTPS token, or Azure DevOps PAT so Argo CD can pull this mono-repo.

8. **Bootstrap app (when child apps exist)** — Copy `gitops/bootstrap/root-app.yaml.example` → `root-app.yaml`, set `repoURL`, apply: `kubectl apply -n argocd -f gitops/bootstrap/root-app.yaml`.

---

## Checklist

- [ ] `kubectl get pods -A`: platform namespaces healthy.
- [ ] Test `Ingress` gets an external IP / hostname; DNS record appears if external-dns is on.
- [ ] Argo CD UI login works; repo connection test succeeds.

---

## Your notes / extra steps

-
