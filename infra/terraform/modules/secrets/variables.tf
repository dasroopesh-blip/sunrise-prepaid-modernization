# modules/secrets/variables.tf

variable "project" {
  description = "Project name prefix."
  type        = string
}

variable "environment" {
  description = "Environment name."
  type        = string
}

variable "kms_key_arn" {
  description = "KMS key ARN used to encrypt the secrets."
  type        = string
}

variable "secret_names" {
  description = "Logical secret names to create (e.g., sqlserver, aurora)."
  type        = list(string)
  default     = ["sqlserver-admin", "aurora-admin", "dms-user"]
}

variable "default_username" {
  description = "Initial username stored in each secret."
  type        = string
  default     = "sunrise_admin"
}
