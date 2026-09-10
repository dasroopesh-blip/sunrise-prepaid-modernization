# environments/staging/variables.tf

variable "project" {
  description = "Project name prefix."
  type        = string
  default     = "sunrise"
}

variable "environment" {
  description = "Environment name."
  type        = string
  default     = "staging"
}

variable "aws_region" {
  description = "Primary AWS region."
  type        = string
  default     = "us-east-1"
}

variable "dr_region" {
  description = "DR (secondary) AWS region."
  type        = string
  default     = "us-west-2"
}

variable "vpc_cidr" {
  description = "VPC CIDR block (distinct from dev/prod to allow peering)."
  type        = string
  default     = "10.30.0.0/16"
}

variable "az_count" {
  description = "Number of AZs to spread across."
  type        = number
  default     = 3
}

variable "allowed_ingress_cidrs" {
  description = "CIDRs allowed to reach the public ALB. Restrict in staging."
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "alert_emails" {
  description = "Emails subscribed to ops alerts."
  type        = list(string)
  default     = []
}

# ---- DMS source (SQL Server) connection ----
variable "dms_source_server" {
  description = "SQL Server source host."
  type        = string
  default     = "10.30.130.10"
}
variable "dms_source_database" {
  description = "Source database name."
  type        = string
  default     = "sunrise"
}
variable "dms_source_username" {
  description = "Source DB username."
  type        = string
  default     = "dms_user"
}
variable "dms_source_password" {
  description = "Source DB password (inject via CI/secret; do NOT commit)."
  type        = string
  sensitive   = true
  default     = "CHANGE_ME_VIA_SECRET"
}

variable "dms_target_username" {
  description = "Target DB username."
  type        = string
  default     = "sunrise_admin"
}
variable "dms_target_password" {
  description = "Target DB password (inject via CI/secret; do NOT commit)."
  type        = string
  sensitive   = true
  default     = "CHANGE_ME_VIA_SECRET"
}
