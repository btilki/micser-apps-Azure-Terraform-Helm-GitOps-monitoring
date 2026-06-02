# Runbook: Ingress HTTP 5xx triage

## Symptoms

- Browsers or `curl` show **502 / 503 / 504** to prod (or stage) hostnames.
- Grafana / Alertmanager: **BoutiqueIngress5xxBurst** or **BoutiqueHighHttp5xxRatio**.
- Users see intermittent failures while **cert** still appears valid.

## Immediate checks

1. **DNS / edge:** Confirm hostname resolves to the **ingress controller LoadBalancer** (not stale IP).
   ```bash
   kubectl get svc -n ingress-nginx
   ```
2. **Ingress object:**
   ```bash
   kubectl get ingress -n prod
   kubectl describe ingress -n prod <name>
   ```
3. **Backend pods:** Ready? Same namespace as Service?
   ```bash
   kubectl get pods,svc,endpoints -n prod
   ```
4. **Ingress controller:** Pods **Running**? Admission webhook errors during apply?
   ```bash
   kubectl get pods -n ingress-nginx
   kubectl logs -n ingress-nginx deploy/ingress-nginx-controller --tail=100
   ```
5. **Recent changes:** Git diff on `gitops/envs/prod/values-*.yaml` (replica, resources, probes) and last Argo Sync.

## Rollback / mitigation

| Cause | Mitigation |
|--------|------------|
| **No healthy endpoints** | Fix **CrashLoop** / **ImagePull** pods (see [prod-rollback](./prod-rollback.md)); scale replicas if **Pending** due to capacity. |
| **Wrong Service port / chart** | Correct Helm values; merge; Argo Sync. |
| **Ingress controller down / webhook 502** | Restart controller pod; ensure controller schedules off **unhealthy nodes**; fix **CNI** if probes fail cluster-wide. |
| **TLS / cert issue** | See [certificate renewal / expiry](./certificate-renewal-expiry.md). |
| **Overload / timeouts** | Temporarily increase **ingress proxy timeouts** or **pod resources** via GitOps; scale replicas. |

After mitigation, confirm:
```bash
curl -sS -o /dev/null -w "%{http_code}\n" https://boutique.example.com/
```

## Owner / escalation

| Tier | Who | When |
|------|-----|------|
| **L1** | On-call engineer | Ingress describe, backend pods, controller logs |
| **L2** | App team + `prod-gitops-approvers` | Values/Helm fixes, prod PRs |
| **L3** | Platform (AKS / network) | CNI, LB, or node pool failures |

Escalate if **multiple namespaces** fail through the same controller (likely **ingress** or **network** layer).
