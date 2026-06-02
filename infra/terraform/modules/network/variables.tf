variable "location" {
  type        = string
  description = "Azure region"
}

variable "tags" {
  type        = map(string)
  default     = {}
  description = "Tags for resources"
}

variable "resource_group_name" {
  type        = string
  description = "Resource group containing the VNet"
}

variable "vnet_name" {
  type        = string
  description = "Virtual network name"
}

variable "address_space" {
  type        = list(string)
  default     = ["10.20.0.0/16"]
  description = "VNet address space"
}

variable "aks_subnet_prefix" {
  type        = string
  default     = "10.20.1.0/24"
  description = "Subnet CIDR for AKS nodes"
}

variable "pe_subnet_prefix" {
  type        = string
  default     = "10.20.2.0/27"
  description = "Subnet CIDR for private endpoints"
}

variable "bastion_subnet_prefix" {
  type        = string
  default     = "10.20.3.0/27"
  description = "Subnet CIDR for optional Bastion"
}
