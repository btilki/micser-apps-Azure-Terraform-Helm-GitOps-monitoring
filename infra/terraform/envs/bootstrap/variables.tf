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
    env        = "shared"
  }
}

variable "storage_account_name" {
  type        = string
  description = "Globally unique, lowercase alphanumeric, 3-24 chars (e.g. stboutiquetfstateweu)"
}
