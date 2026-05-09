# Runbook: Certificate renewal / expiry incident

## Symptoms

- Browser **certificate warning** or **NET::ERR_CERT_AUTHORITY_INVALID** on prod ingress hostnames (e.g. `boutique.biroltilki.art`).
- `kubectl describe certificate -n prod` shows **not Ready** or **expiry** soon.
- Alert **BoutiqueCertificateExpiresSoon** or cert-manager **CertificateExpiring** / **CertificateNotReady**.
- Ingress serves default cert or HTTP only.

## Immediate checks

1. **Certificate CR:**
   ```bash
   kubectl get certificate -n prod
   kubectl describe certificate -n prod <name>
   ```
2. **cert-manager:** Pods and logs.
   ```bash
   kubectl get pods -n cert-manager
   kubectl logs -n cert-manager deploy/cert-manager --tail=80
   ```
3. **Challenge / order** (ACME):
   ```bash
   kubectl get certificaterequest,order,challenge -n prod
   ```
4. **HTTP-01 reachability:** From the internet, `http://<host>/.well-known/acme-challenge/...` must hit the cluster; **port 80** open on the **ingress LB**.
5. **ClusterIssuer:** `letsencrypt-prod` exists and matches ingress **annotations** (`cert-manager.io/cluster-issuer`).

## Rollback / mitigation

| Cause | Mitigation |
|--------|------------|
| **HTTP-01 blocked** | Fix DNS → LB, ingress **class**, firewall; ensure **nginx** serves challenges. |
| **Rate limit / bad issuer config** | Check cert-manager logs; wait or use staging issuer for tests; fix **email/solver** settings on **ClusterIssuer**. |
| **Certificate stuck** | `kubectl delete challenge ...` cautiously to retry; or delete and recreate **Certificate** if safe. |
| **Secret missing / wrong reference** | Align **ingress TLS secretName** in `gitops/envs/prod/values-*.yaml` with Certificate **secretName**; merge + Argo Sync. |
| **Expiry imminent** | Force renewal: annotate Certificate `cert-manager.io/issue-temporary-certificate: "true"` only per cert-manager docs; prefer fixing ACME path first. |

After fix:
```bash
kubectl get certificate -n prod
openssl s_client -connect boutique.biroltilki.art:443 -servername boutique.biroltilki.art </dev/null 2>/dev/null | openssl x509 -noout -dates
```

## Owner / escalation

| Tier | Who | When |
|------|-----|------|
| **L1** | On-call engineer | Describe certificate, challenges, ingress |
| **L2** | `prod-gitops-approvers` | GitOps changes to issuer annotations / TLS secret names |
| **L3** | Platform + DNS owner | LB, DNS, **Let's Encrypt** rate limits, identity for cert-manager (Azure WI) |

Escalate if **all** certs fail (issuer or **cluster-wide** DNS/LB issue).
