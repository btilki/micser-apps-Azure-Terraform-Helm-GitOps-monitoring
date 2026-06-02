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

variable "identity_name" {
  type        = string
  description = "User-assigned managed identity name (e.g. id-boutique-dev-frontend-weu)"
}

variable "oidc_issuer_url" {
  type        = string
  description = "AKS OIDC issuer URL from shared stack output"
}

variable "federated_credential_name" {
  type        = string
  description = "Name for azurerm_federated_identity_credential"
}

variable "federated_subject" {
  type        = string
  description = "Kubernetes SA subject, e.g. system:serviceaccount:dev:frontend"
}

variable "key_vault_id" {
  type        = string
  description = "Scope for Key Vault Secrets User role assignment"
}
