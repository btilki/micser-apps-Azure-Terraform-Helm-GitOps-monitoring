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

variable "enable_subscription_budget" {
  type        = bool
  default     = false
  description = "When true and budget_notification_emails is non-empty, create a monthly Consumption budget on the current subscription (Phase 8)."
}

variable "budget_name" {
  type        = string
  default     = "boutique-subscription-monthly"
  description = "Azure Consumption budget resource name."
}

variable "budget_monthly_amount" {
  type        = number
  default     = 50
  description = "Monthly budget amount in the subscription billing currency."
}

variable "budget_period_start" {
  type        = string
  default     = "2026-05-01T00:00:00Z"
  description = "Budget time_period start (RFC3339, typically first day of month UTC)."
}

variable "budget_period_end" {
  type        = string
  default     = "2030-12-31T23:59:59Z"
  description = "Budget time_period end (RFC3339)."
}

variable "budget_notification_emails" {
  type        = list(string)
  default     = []
  description = "Email recipients for the 80% actual spend notification. Budget is not created if this list is empty."
}
