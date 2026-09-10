# modules/observability/variables.tf

variable "project" {
  description = "Project name prefix."
  type        = string
}

variable "environment" {
  description = "Environment name."
  type        = string
}

variable "kms_key_arn" {
  description = "KMS key ARN for log/topic encryption."
  type        = string
}

variable "log_retention_days" {
  description = "How long to retain CloudWatch logs."
  type        = number
  default     = 90
}

variable "alert_emails" {
  description = "Email addresses subscribed to ops alerts."
  type        = list(string)
  default     = []
}

variable "recon_dlq_name" {
  description = "Name of the reconciliation DLQ to alarm on (empty to skip)."
  type        = string
  default     = ""
}
