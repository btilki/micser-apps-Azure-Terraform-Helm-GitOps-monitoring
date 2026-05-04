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

variable "registry_name" {
  type        = string
  description = "Globally unique, alphanumeric only (e.g. acrboutiquedevweu)"
}

variable "sku" {
  type    = string
  default = "Standard"
}

variable "public_network_access_enabled" {
  type        = bool
  default     = false
  description = "Set false when using private endpoint only"
}

variable "pe_subnet_id" {
  type        = string
  description = "Subnet for private endpoint"
}

variable "private_dns_zone_acr_id" {
  type        = string
  description = "privatelink.azurecr.io zone in shared network RG"
}

variable "kubelet_object_id" {
  type        = string
  description = "AKS kubelet identity object id for AcrPull"
}

variable "georeplications" {
  type        = list(string)
  default     = []
  description = "Optional secondary region names for geo-replication (Premium)"
}
