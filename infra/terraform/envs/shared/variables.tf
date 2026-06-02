variable "location" {
  type    = string
  default = "westeurope"
}

variable "dns_zone_name" {
  type    = string
  default = "example.com"
}

variable "kubernetes_version" {
  type        = string
  description = "Pin to a supported patch version in your Azure region (see `az aks get-versions --location <region>`). Leave null to use the region default from Terraform."
  default     = null
  nullable    = true
}

variable "aks_create_workload_node_pools" {
  type        = bool
  description = "Create dev/stage/prod node pools (npdev, npstg, npprod) with env taints. Disable for first bootstrap if your subscription has low regional vCPU quota."
  default     = false
}

variable "aks_create_user_node_pool" {
  type        = bool
  description = "Create an untainted user node pool for platform charts (ingress, external-dns, monitoring) and workloads without env taints. Recommended when only the system pool exists."
  default     = true
}

variable "aks_user_pool" {
  type = object({
    vm_size   = string
    min_count = number
    max_count = number
  })
  description = "General-purpose user node pool (no taints; label workload=general)."
  default = {
    vm_size   = "Standard_B2s"
    min_count = 1
    max_count = 3
  }
}

variable "aks_system_pool" {
  type = object({
    vm_size   = string
    min_count = number
    max_count = number
  })
  description = "VM SKU/counts for the AKS system pool. Prefer a SKU family you have quota for (check Azure Portal → Subscriptions → Usage + quotas)."
  default = {
    vm_size   = "Standard_B2s"
    min_count = 1
    max_count = 3
  }
}

variable "api_server_authorized_ip_ranges" {
  type        = list(string)
  default     = []
  description = "CIDRs allowed to reach the API server; empty uses provider defaults"
}

variable "tags" {
  type = map(string)
  default = {
    project    = "boutique"
    managedBy  = "terraform"
    costCenter = "personal-demo"
    env        = "shared"
  }
}

variable "owner_email" {
  type        = string
  description = "Tagged on resources (architecture §15)"
  default     = "you@example.com"
}
