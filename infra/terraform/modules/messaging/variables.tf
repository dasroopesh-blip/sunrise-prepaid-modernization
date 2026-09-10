# modules/messaging/variables.tf

variable "project" {
  description = "Project name prefix."
  type        = string
}

variable "environment" {
  description = "Environment name."
  type        = string
}

variable "kms_key_arn" {
  description = "KMS key ARN for stream/queue encryption."
  type        = string
}
