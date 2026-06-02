Place **Argo CD `Application`** manifests here (child apps). The root app in `root-app.yaml` points at this directory with `directory.recurse: true` so Argo CD creates each child Application in the cluster.

**Dev app-of-apps:** `apps-dev.yaml` syncs the **`gitops/apps/dev/`** folder (per-microservice `*-dev.yaml` manifests). Add new dev workloads by adding files under `gitops/apps/dev/`, not by duplicating umbrella apps here.

Alternatively, replace this layout with **Kustomize** or an **ApplicationSet** and point the root app at that path instead.
