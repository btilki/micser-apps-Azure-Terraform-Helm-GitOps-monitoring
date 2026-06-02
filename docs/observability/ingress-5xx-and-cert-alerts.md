# Ingress 5xx alerts and certificate expiry alerts

How **kube-prometheus-stack** in this repo turns NGINX Ingress and cert-manager metrics into Alertmanager notifications—and what **5xx** means in that path.

**Related:** [gitops/apps/platform/kube-prometheus-stack/values.yaml](../../gitops/apps/platform/kube-prometheus-stack/values.yaml) · [ingress-5xx runbook](../runbooks/ingress-5xx-triage.md) · [certificate runbook](../runbooks/certificate-renewal-expiry.md) · [grafana-dashboards](../runbooks/grafana-dashboards.md)

---

## Where this fits in the platform

```text
User/browser
    │  HTTPS
    ▼
NGINX Ingress Controller  ──metrics──► Prometheus  ──rules──► Alertmanager  ──► Slack/email/webhook
    │                                      ▲
    │  TLS Secret (from cert-manager)      │
    ▼                                      │
frontend Service/Pods              cert-manager ──metrics──► (certificate expiry rules)
```

- **Ingress 5xx alerts** watch **HTTP responses** the ingress controller returns (or proxies)—status codes **500–599**.
- **Certificate expiry alerts** watch **cert-manager** metrics about **TLS certificate NotAfter time**—not HTTP status codes.

A broken certificate often shows up in the **browser** as a trust error (`NET::ERR_CERT_*`), not necessarily as a counted **5xx** on the ingress metric. Both alert families matter; they detect different failure modes.

---

## Part 1 — HTTP 5xx and ingress metrics

### What “5xx” means

HTTP status codes in the **5xx range** mean the **server** (or something acting as server from the client’s view) failed to complete the request successfully:

| Code | Typical meaning in this project |
|------|----------------------------------|
| **500** | Internal error in the app or ingress (misconfiguration, panic, upstream returned 500). |
| **502** | **Bad Gateway** — ingress could not get a valid response from the **backend Service** (no endpoints, connection refused, wrong port). |
| **503** | **Service Unavailable** — no ready backends, overload, or deliberate “no server” (e.g. `googleDemo.enabled: true` without real demo backends → **503**). |
| **504** | **Gateway Timeout** — backend too slow; ingress gave up waiting. |

**4xx** (400–499) are **client** errors (404, 401). The custom rules in this repo **do not** alert on 4xx—only `status=~"5.."`.

### Where the metric comes from

The NGINX Ingress Controller exposes Prometheus metrics, including:

```text
nginx_ingress_controller_requests{status="502", ...}
nginx_ingress_controller_requests{status="503", ...}
```

Each request through the controller increments a counter labeled by **status code** (and ingress, namespace, etc., depending on scrape config).

**Requirement:** Prometheus must **scrape** the ingress controller metrics endpoint. The values file comments say:

> Ensure NGINX Ingress Controller metrics are scraped (ServiceMonitor / PodMonitor).

If scraping is not enabled when you install `ingress-nginx`, the 5xx rules exist but **never fire** (no data).

### The two custom alerts (Prometheus rules)

Defined in `gitops/apps/platform/kube-prometheus-stack/values.yaml` under `additionalPrometheusRulesMap.boutique-custom-alerts`.

#### `BoutiqueIngress5xxBurst` (short window, higher threshold)

**Intent:** Catch a **sudden** spike—many failures compared to total traffic in the last **5 minutes**.

**Expression (conceptually):**

```promql
sum(rate(nginx_ingress_controller_requests{status=~"5.."}[5m]))
/
sum(rate(nginx_ingress_controller_requests[5m]))
> 0.05
```

- **Numerator:** rate of requests with status 500–599.
- **Denominator:** rate of **all** ingress requests (clamped to avoid divide-by-zero).
- **Threshold:** more than **5%** of traffic is 5xx.
- **`for: 5m`:** condition must hold **5 minutes** before firing.

**When it fires:** e.g. all backends go unhealthy at once, bad deploy, ingress misroute—**fast** user-visible outage.

#### `BoutiqueHighHttp5xxRatio` (longer window, lower threshold)

**Intent:** Catch **sustained** poor quality—even if not a huge spike.

- Window: **10 minutes**
- Threshold: more than **1%** 5xx
- **`for: 10m`**

**When it fires:** slow leak—intermittent 502s, one bad pod in a small replica set, timeouts under load.

### Alertmanager routing

Both alerts match:

```yaml
alertname =~ "BoutiqueIngress5xxBurst|BoutiqueHighHttp5xxRatio"
```

They go to receiver **`boutique-on-call`** (Slack, email, webhook—after you replace `REPLACE_*` placeholders).

### What to do when they fire

Follow [ingress-5xx-triage](../runbooks/ingress-5xx-triage.md):

1. Confirm hostname → correct ingress **LoadBalancer** IP.
2. `kubectl get ingress,svc,endpoints,pods` in the affected namespace (`dev`, `stage`, `prod`).
3. Ingress controller logs: `kubectl logs -n ingress-nginx deploy/ingress-nginx-controller`.
4. Recent GitOps / Argo sync on `gitops/envs/<env>/values-*.yaml`.

**Common root causes in this repo:**

- Pods **CrashLoop** or **ImagePullBackOff** (bad digest, ACR pull).
- **No endpoints** (Service selector mismatch, scale to zero).
- **503** with `googleDemo.enabled: true` but no upstream Google demo services.
- **NetworkPolicy** blocking ingress → pod traffic.
- Ingress controller or node unhealthy.

Verify recovery:

```bash
curl -sS -o /dev/null -w "%{http_code}\n" -I https://<your-storefront-host>/
```

Expect **200** or a normal redirect—not **5xx**.

---

## Part 2 — cert-manager metrics and expiry alerts

### What this detects

TLS certificates for storefront hostnames are issued by **cert-manager** (ClusterIssuer `letsencrypt-prod`, **DNS-01** against Azure DNS in this design). Each `Certificate` resource has an expiration time.

If renewal fails, the cert expires and browsers reject HTTPS—even if the app pods are healthy. That is **not** always visible as ingress **5xx** in the same metrics (clients may fail before a normal HTTP status is recorded).

### Where the metric comes from

Custom rule uses:

```text
certmanager_certificate_expiration_timestamp_seconds
```

That metric is exported by **cert-manager** when its Prometheus integration is scraped.

**Requirement:** Enable cert-manager **ServiceMonitor** (or equivalent scrape config). The values file states:

> Enable cert-manager ServiceMonitor if you want CertificateExpiresSoon to fire.

Without scrape, the rule is loaded but has **no series** → alert never fires.

### Alert: `BoutiqueCertificateExpiresSoon`

**Expression (conceptually):**

```promql
min by (namespace, name) (
  certmanager_certificate_expiration_timestamp_seconds - time()
) < 14 * 24 * 3600
```

- For each Certificate (by namespace and name), time until expiry **less than 14 days**.
- **`for: 1h`:** must stay true for an hour (reduces noise from transient blips).

**Severity:** `warning` — time to fix renewal before hard outage.

**Also routed** to `boutique-on-call`, grouped with cert-manager upstream alert names if you enable default chart rules:

```yaml
BoutiqueCertificateExpiresSoon|CertManagerCertificateExpiresSoon|CertManagerCertificateNotReady
```

### DNS-01 vs HTTP-01 (this repo)

ClusterIssuer in `gitops/apps/platform/cert-manager/clusterissuer.yaml` uses **Azure DNS DNS-01**, not HTTP-01. Renewal depends on:

- cert-manager pod health and **Workload Identity** to Azure DNS.
- Correct **managed identity** on the ClusterIssuer (no stale `YOUR_*` placeholders).
- DNS zone delegation still pointing at your environment.

If challenges stick with an **old** managed identity client ID after you rotate IDs, delete stale `Challenge` objects (see [certificate runbook](../runbooks/certificate-renewal-expiry.md) and Phase 3 TLS notes).

### What to do when it fires

Follow [certificate-renewal-expiry](../runbooks/certificate-renewal-expiry.md):

```bash
kubectl get certificate,certificaterequest,order,challenge -n <env>
kubectl describe certificate -n <env> <name>
kubectl logs -n cert-manager deploy/cert-manager --tail=80
```

Check the live cert:

```bash
openssl s_client -connect boutique.example.com:443 -servername boutique.example.com </dev/null 2>/dev/null | openssl x509 -noout -dates
```

---

## Part 3 — 5xx vs certificate problems (don’t confuse them)

| Symptom | Likely layer | Alert that may fire |
|---------|----------------|---------------------|
| Browser “connection not private” / cert expired | cert-manager / TLS Secret | `BoutiqueCertificateExpiresSoon` |
| Browser **502 Bad Gateway** | Ingress → no healthy backend | `BoutiqueIngress5xxBurst` / `BoutiqueHighHttp5xxRatio` |
| **503** on storefront URL | App routing, demo config, or no endpoints | Ingress 5xx rules |
| Valid cert but slow pages | App performance, not always 5xx | May not alert unless timeouts → **504** |

You can have **valid TLS** and still see **502/503** if pods are broken. You can have **healthy pods** and still break HTTPS if the **Certificate** is expired.

---

## Part 4 — Enable and verify in your cluster

### 1. Install / upgrade monitoring stack

```bash
helm upgrade --install kube-prometheus-stack prometheus-community/kube-prometheus-stack \
  -n monitoring --create-namespace \
  -f gitops/apps/platform/kube-prometheus-stack/values.yaml
```

Replace `REPLACE_*` receivers before relying on notifications in production.

### 2. Confirm ingress metrics exist

In Prometheus UI or Grafana → explore:

```promql
sum(rate(nginx_ingress_controller_requests[5m])) by (status)
```

You should see series for `200`, `304`, `502`, etc. If empty, fix ingress ServiceMonitor / metrics Service.

### 3. Confirm cert-manager metrics exist

```promql
certmanager_certificate_expiration_timestamp_seconds
```

If empty, enable cert-manager scraping in the cert-manager Helm chart or kube-prometheus-stack integrations.

### 4. Test Alertmanager (optional)

Port-forward Alertmanager and POST a test alert (see comments at top of `values.yaml`).

---

## Summary

| Topic | Metric source | Alerts | Runbook |
|-------|---------------|--------|---------|
| **Ingress 5xx** | `nginx_ingress_controller_requests{status=~"5.."}` | Burst >5% (5m), Sustained >1% (10m) | [ingress-5xx-triage](../runbooks/ingress-5xx-triage.md) |
| **Cert expiry** | `certmanager_certificate_expiration_timestamp_seconds` | Expires in <14 days (1h) | [certificate-renewal-expiry](../runbooks/certificate-renewal-expiry.md) |

Both are defined in **`gitops/apps/platform/kube-prometheus-stack/values.yaml`** and documented for operators in **`docs/runbooks/`**.
