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
    env        = "prod"
  }
}

variable "owner_email" {
  type    = string
  default = "you@example.com"
}

variable "shared_state_resource_group_name" {
  type = string
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

variable "promotion_service_principal_object_id" {
  type        = string
  default     = ""
  description = "Optional. Promotion SP object ID: AcrPush on prod ACR. Reader on RGs is managed in stage stack. Set in terraform.tfvars (gitignored)."
}
