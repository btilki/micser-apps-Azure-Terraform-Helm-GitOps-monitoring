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
  default = "btilki@gmail.com"
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
