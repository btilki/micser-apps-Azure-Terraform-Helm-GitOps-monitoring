# Grafana dashboards for releases

**Goal:** Quick visibility during Phase 9 / release monitoring: capacity, ingress errors, pod health, certificates.

## Access

- Grafana URL is documented in the root [README](../../README.md) (e.g. `https://grafana.<your-domain>`).
- Sign-in uses whatever you configured on `kube-prometheus-stack` (OAuth / admin secret). Retrieve admin bootstrap secret only for break-glass:
  ```bash
  kubectl get secret -n monitoring kube-prometheus-stack-grafana -o jsonpath='{.data.admin-password}' | base64 -d && echo
  ```

## Built-in dashboards (kube-prometheus-stack)

The [kube-prometheus-stack](https://github.com/prometheus-community/helm-charts/tree/main/charts/kube-prometheus-stack) chart ships Grafana dashboards when Grafana is enabled. After install, browse **Dashboards → Browse** and search for:

| Topic | Example dashboard names (may vary by chart version) |
|-------|--------------------------------------------------------|
| **Cluster capacity** | “Kubernetes / Compute Resources / Cluster”, “Node Exporter / Nodes” |
| **Ingress latency / errors** | “NGINX Ingress controller” (requires ingress controller metrics scraped; see `gitops/apps/platform/kube-prometheus-stack/values.yaml` and architecture doc) |
| **Pod health / restarts** | “Kubernetes / Compute Resources / Namespace (Pods)”, “Kubernetes / Kubelet” |
| **Certificates** | cert-manager dashboards if enabled; custom rules `BoutiqueCertificateExpiresSoon` in the same values file |

Import or enable any missing upstream dashboard from Grafana **Dashboards → New → Import** using the dashboard ID from [grafana.com/grafana/dashboards](https://grafana.com/grafana/dashboards/) (e.g. search “nginx ingress prometheus”).

## Alertmanager

- UI is usually not public; use port-forward:
  ```bash
  kubectl -n monitoring port-forward svc/kube-prometheus-stack-alertmanager 9093:9093
  ```
  Then open `http://127.0.0.1:9093`.
- Confirm receivers in `values.yaml` (`boutique-on-call`) are wired to your real Slack/email/webhook (replace `REPLACE_*` placeholders).

## Day-2

- Keep dashboards **small and actionable**; link broken panels to [runbooks README](./README.md).
- When onboarding a new metric, add one panel and one alert with a runbook link.
