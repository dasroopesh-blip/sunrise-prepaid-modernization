# modules/settlement/variables.tf

variable "project" {
  description = "Project name prefix."
  type        = string
}

variable "environment" {
  description = "Environment name."
  type        = string
}

variable "kms_key_arn" {
  description = "KMS key ARN for S3 encryption."
  type        = string
}

variable "glue_role_arn" {
  description = "IAM role ARN the Glue job runs as (from the iam module)."
  type        = string
}

variable "bucket_suffix" {
  description = "Unique suffix to keep S3 bucket names globally unique."
  type        = string
}

variable "glue_worker_type" {
  description = "Glue worker size (G.1X, G.2X, ...)."
  type        = string
  default     = "G.2X"
}

variable "glue_number_of_workers" {
  description = "Number of Glue workers (parallelism for settlement)."
  type        = number
  default     = 10
}
