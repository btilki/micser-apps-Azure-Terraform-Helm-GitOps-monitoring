Place **Argo CD `Application`** manifests here (child apps). The root app in `root-app.yaml` should point at this directory with `directory.recurse: true` so Argo CD creates each child Application in the cluster.

Alternatively, replace this layout with **Kustomize** or an **ApplicationSet** and point the root app at that path instead.
