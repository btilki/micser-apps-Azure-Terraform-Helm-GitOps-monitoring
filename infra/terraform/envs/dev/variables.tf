variable "location" {
  type    = string
  default = "westeurope"
}

variable "tags" {
  type = map(string)
  default = {
    project    = "boutique"
    managedBy  = "terraform"
    costCenter = "personal-demo"
    env        = "dev"
  }
}

variable "owner_email" {
  type    = string
  default = "you@example.com"
}

variable "shared_state_resource_group_name" {
  type        = string
  description = "TF state RG (bootstrap output)"
}

variable "shared_state_storage_account_name" {
  type = string
}

variable "shared_state_container_name" {
  type    = string
  default = "tfstate-shared"
}

variable "shared_state_key" {
  type    = string
  default = "boutique-shared.tfstate"
}

# Enterprise application Object ID (not Application (client) ID) for the app behind
# Azure DevOps `promotion-azure-connection`. DevOps → service connection → Manage service principal → Object ID.
variable "promotion_service_principal_object_id" {
  type        = string
  default     = ""
  description = "Optional. Promotion SP object ID for AcrPull on dev ACR. Set in terraform.tfvars (gitignored)."
}
