# Phase 2 — Cluster bootstrap

[← Phase 1](phase-01-terraform-foundation.md) · [Index](README.md) · [Phase 3 →](phase-03-first-service-frontend.md)

**Goal:** Install base platform components so GitOps deployments can run on AKS.

## Process (brief)

Install platform services in this order: ingress, certificates, DNS automation, monitoring, Argo CD. Then connect repo and bootstrap the root app.

## Step-by-step

1. Verify cluster context, AKS connectivity, and Helm:
   ```bash
   kubectl get nodes
   kubectl config current-context
   helm version
   ```
2. Install `ingress-nginx` and bind it to the static public IP from shared Terraform outputs:
   ```bash
   cd infra/terraform/envs/shared
   export INGRESS_IP="$(terraform output -raw ingress_public_ip)"
   echo "$INGRESS_IP"

   helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
   helm repo update

   kubectl create ns ingress-nginx --dry-run=client -o yaml | kubectl apply -f -

   helm upgrade --install ingress-nginx ingress-nginx/ingress-nginx \
     -n ingress-nginx \
     --set controller.service.type=LoadBalancer \
     --set controller.service.loadBalancerIP="$INGRESS_IP" \
     --set controller.service.annotations."service\.beta\.kubernetes\.io/azure-load-balancer-resource-group"="rg-boutique-shared-weu" \
     --set controller.service.annotations."service\.beta\.kubernetes\.io/azure-load-balancer-health-probe-request-path"="/healthz"

   kubectl get svc -n ingress-nginx ingress-nginx-controller -o wide
   kubectl get pods -n ingress-nginx
   ```
3. Install `cert-manager` and apply ClusterIssuer `letsencrypt-prod`:
   ```bash
   cd path/to/clone

   helm repo add jetstack https://charts.jetstack.io
   helm repo update

   kubectl create ns cert-manager --dry-run=client -o yaml | kubectl apply -f -

   helm upgrade --install cert-manager jetstack/cert-manager \
     -n cert-manager \
     --create-namespace \
     --set crds.enabled=true \
     -f gitops/apps/platform/cert-manager/values.yaml

   kubectl apply -f gitops/apps/platform/cert-manager/clusterissuer.yaml

   kubectl get pods -n cert-manager
   kubectl get clusterissuer letsencrypt-prod
   ```
4. Install `external-dns` and configure Azure DNS permissions:
   - Required roles for external-dns managed identity:
     - `DNS Zone Contributor` on DNS zone scope
     - `Reader` on DNS resource group scope (some environments require this)
   ```bash
   export SUBSCRIPTION_ID="$(az account show --query id -o tsv)"
   export DNS_ZONE_RG="rg-boutique-shared-weu"
   export DNS_ZONE_NAME="example.com"
   export EXTERNAL_DNS_MI_NAME="id-boutique-external-dns-weu"
   export AKS_RG="rg-boutique-shared-weu"
   export AKS_NAME="aks-boutique-weu"
   export EXTERNAL_DNS_MI_CLIENT_ID="$(az identity show -g "$DNS_ZONE_RG" -n "$EXTERNAL_DNS_MI_NAME" --query clientId -o tsv)"
   export EXTERNAL_DNS_PRINCIPAL_ID="$(az identity show -g "$DNS_ZONE_RG" -n "$EXTERNAL_DNS_MI_NAME" --query principalId -o tsv)"
   export DNS_ZONE_ID="$(az network dns zone show -g "$DNS_ZONE_RG" -n "$DNS_ZONE_NAME" --query id -o tsv)"
   export DNS_RG_ID="$(az group show -n "$DNS_ZONE_RG" --query id -o tsv)"
   export AKS_OIDC_ISSUER="$(az aks show -g "$AKS_RG" -n "$AKS_NAME" --query oidcIssuerProfile.issuerUrl -o tsv)"

   # If identity does not exist yet, create it first:
   # az identity create -g "$DNS_ZONE_RG" -n "$EXTERNAL_DNS_MI_NAME" -l westeurope

   az role assignment create \
     --assignee-object-id "$EXTERNAL_DNS_PRINCIPAL_ID" \
     --assignee-principal-type ServicePrincipal \
     --role "DNS Zone Contributor" \
     --scope "$DNS_ZONE_ID"

   az role assignment create \
     --assignee-object-id "$EXTERNAL_DNS_PRINCIPAL_ID" \
     --assignee-principal-type ServicePrincipal \
     --role "Reader" \
     --scope "$DNS_RG_ID"

   # Required for AKS Workload Identity (external-dns service account subject)
   az identity federated-credential create \
     --name "fic-external-dns" \
     --identity-name "$EXTERNAL_DNS_MI_NAME" \
     --resource-group "$DNS_ZONE_RG" \
     --issuer "$AKS_OIDC_ISSUER" \
     --subject "system:serviceaccount:external-dns:external-dns" \
     --audiences "api://AzureADTokenExchange"
   ```
   ```bash
   cd path/to/clone

   kubectl create ns external-dns --dry-run=client -o yaml | kubectl apply -f -
   kubectl -n external-dns create secret generic external-dns-azure \
     --from-file=azure.json=gitops/apps/platform/external-dns/azure.json \
     --dry-run=client -o yaml | kubectl apply -f -

   helm repo add external-dns https://kubernetes-sigs.github.io/external-dns/
   helm repo update

   helm upgrade --install external-dns external-dns/external-dns \
     -n external-dns \
     -f gitops/apps/platform/external-dns/values.yaml

   kubectl get pods -n external-dns
   kubectl logs -n external-dns deploy/external-dns --tail=100
   ```
5. Install `kube-prometheus-stack` in `monitoring`:
   ```bash
   cd path/to/clone

   helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
   helm repo update

   helm upgrade --install kube-prometheus-stack prometheus-community/kube-prometheus-stack \
     -n monitoring \
     --create-namespace \
     -f gitops/apps/platform/kube-prometheus-stack/values.yaml

   kubectl get pods -n monitoring
   ```
6. Install Argo CD in `argocd` and retrieve admin password:
   ```bash
   kubectl create ns argocd --dry-run=client -o yaml | kubectl apply -f -

   helm repo add argo https://argoproj.github.io/argo-helm
   helm repo update

   helm upgrade --install argocd argo/argo-cd \
     -n argocd \
     --set server.service.type=LoadBalancer

   kubectl rollout status deploy/argocd-server -n argocd --timeout=180s
   ```
   ```bash
   kubectl get secret argocd-initial-admin-secret -n argocd -o jsonpath="{.data.password}" | base64 --decode && echo
   ```
7. In Argo CD UI (`Settings -> Repositories`), connect this repo with valid credentials (PAT/SSH):
   - if using GitHub, set `repoURL` as `https://github.com/<ORG>/<REPO>.git`
   - if using Azure Repos, set `repoURL` as `https://dev.azure.com/<ORG>/<PROJECT>/_git/<REPO>`
   - verify repository status is `Successful`
   - for private GitHub repos, add credentials in Argo CD (UI or secret):
   ```bash
   GITHUB_TOKEN="$(gh auth token)"
   kubectl -n argocd create secret generic repo-github-boutique \
     --from-literal=type=git \
     --from-literal=url=https://github.com/<ORG>/<REPO>.git \
     --from-literal=username=x-access-token \
     --from-literal=password="$GITHUB_TOKEN" \
     --dry-run=client -o yaml | kubectl apply -f -
   kubectl -n argocd label secret repo-github-boutique argocd.argoproj.io/secret-type=repository --overwrite
   ```
8. Use bootstrap app manifest:
   ```bash
   cp gitops/bootstrap/root-app.yaml.example gitops/bootstrap/root-app.yaml
   # update repoURL/branch if required
   kubectl apply -n argocd -f gitops/bootstrap/root-app.yaml
   ```
9. Validate platform health and GitOps sync:
   ```bash
   kubectl get pods -A
   kubectl get ingress -A
   kubectl get certificate -A
   kubectl get applications -n argocd
   ```

### Root Application `boutique-root` synced in Argo CD:

![alt text](./../diagrams/argocd-boutique-root-application-synced.png)

## Done checklist

- Ingress has external address.
- Certificates can be issued.
- ExternalDNS can write records to Azure DNS zone.
- Argo CD can read the repo and sync bootstrap apps.

---

[← Phase 1](phase-01-terraform-foundation.md) · [Index](README.md) · [Phase 3 →](phase-03-first-service-frontend.md)
