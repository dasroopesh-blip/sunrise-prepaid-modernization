# environments/dev/variables.tf

variable "project" {
  description = "Project name prefix."
  type        = string
  default     = "sunrise"
}

variable "environment" {
  description = "Environment name."
  type        = string
  default     = "dev"
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
  description = "VPC CIDR block."
  type        = string
  default     = "10.20.0.0/16"
}

variable "az_count" {
  description = "Number of AZs to spread across."
  type        = number
  default     = 3
}

variable "allowed_ingress_cidrs" {
  description = "CIDRs allowed to reach the public ALB. LOCK DOWN before prod."
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "alert_emails" {
  description = "Emails subscribed to ops alerts."
  type        = list(string)
  default     = []
}

# ---- DMS source (SQL Server) connection ----
# In real use, inject the password from Secrets Manager via CI, not tfvars.
variable "dms_source_server" {
  description = "SQL Server source host (EC2 AG listener or on-prem via VPN)."
  type        = string
  default     = "10.20.130.10"
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

# ---- DMS target (Aurora) auth ----
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
