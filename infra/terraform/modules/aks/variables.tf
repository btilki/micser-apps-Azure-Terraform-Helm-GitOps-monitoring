variable "location" {
  type = string
}

variable "tags" {
  type    = map(string)
  default = {}
}

variable "resource_group_name" {
  type = string
}

variable "cluster_name" {
  type = string
}

variable "dns_prefix" {
  type        = string
  description = "DNS prefix for API server FQDN"
}

variable "kubernetes_version" {
  type        = string
  description = "AKS control plane and default pool version"
}

variable "aks_subnet_id" {
  type = string
}

variable "log_analytics_workspace_id" {
  type        = string
  description = "Optional: enable Container Insights"
  default     = null
}

variable "system_pool" {
  type = object({
    vm_size   = string
    min_count = number
    max_count = number
  })
  default = {
    vm_size   = "Standard_B2s"
    min_count = 1
    max_count = 3
  }
}

variable "create_workload_node_pools" {
  type        = bool
  description = "If true, create dev/stage/prod node pools with env taints (npdev, npstg, npprod). Independent of create_user_node_pool."
  default     = true
}

variable "create_user_node_pool" {
  type        = bool
  description = "If true, create a general-purpose user node pool without taints (schedules ingress, external-dns, prometheus, and unscoped workloads)."
  default     = true
}

variable "user_pool" {
  type = object({
    vm_size   = string
    min_count = number
    max_count = number
  })
  default = {
    vm_size   = "Standard_B2s"
    min_count = 1
    max_count = 3
  }
}

variable "npdev" {
  type = object({
    vm_size   = string
    min_count = number
    max_count = number
  })
  default = {
    vm_size   = "Standard_B2s"
    min_count = 1
    max_count = 3
  }
}

variable "npstg" {
  type = object({
    vm_size   = string
    min_count = number
    max_count = number
  })
  default = {
    vm_size   = "Standard_B2s"
    min_count = 1
    max_count = 3
  }
}

variable "npprod" {
  type = object({
    vm_size   = string
    min_count = number
    max_count = number
    zones     = optional(list(string))
  })
  default = {
    vm_size   = "Standard_B2s"
    min_count = 1
    max_count = 4
  }
}

variable "api_server_authorized_ip_ranges" {
  type        = list(string)
  default     = []
  description = "Restrict API access; empty allows AzurePortal + public (see doc §7)"
}
