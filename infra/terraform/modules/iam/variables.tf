# modules/iam/variables.tf

variable "project" {
  description = "Project name prefix."
  type        = string
}

variable "environment" {
  description = "Environment name."
  type        = string
}

variable "settlement_bucket_arns" {
  description = "S3 bucket ARNs the Glue settlement jobs may access."
  type        = list(string)
  default     = []
}

variable "kms_key_arns" {
  description = "KMS key ARNs the Glue role may use to decrypt/encrypt."
  type        = list(string)
  default     = []
}
