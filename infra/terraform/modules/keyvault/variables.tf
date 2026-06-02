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

variable "keyvault_name" {
  type        = string
  description = "Max 24 chars, globally unique"
}

variable "tenant_id" {
  type        = string
  description = "Azure AD tenant id"
}

variable "pe_subnet_id" {
  type = string
}

variable "private_dns_zone_keyvault_id" {
  type = string
}

variable "purge_protection_enabled" {
  type    = bool
  default = false
}

variable "soft_delete_retention_days" {
  type    = number
  default = 7
}
