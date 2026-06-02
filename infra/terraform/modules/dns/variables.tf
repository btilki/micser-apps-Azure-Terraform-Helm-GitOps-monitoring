variable "resource_group_name" {
  type = string
}

variable "tags" {
  type    = map(string)
  default = {}
}

variable "zone_name" {
  type        = string
  description = "Public DNS zone name (e.g. example.com)"
}
