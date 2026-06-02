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

variable "workspace_name" {
  type        = string
  description = "Log Analytics workspace name"
}

variable "retention_in_days" {
  type    = number
  default = 30
}
