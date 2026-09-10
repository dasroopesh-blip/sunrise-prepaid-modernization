# environments/prod/variables.tf

variable "project" {
  description = "Project name prefix."
  type        = string
  default     = "sunrise"
}

variable "environment" {
  description = "Environment name."
  type        = string
  default     = "prod"
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
  description = "VPC CIDR block (distinct from dev/staging)."
  type        = string
  default     = "10.40.0.0/16"
}

variable "az_count" {
  description = "Number of AZs to spread across (3 for prod HA)."
  type        = number
  default     = 3
}

# PROD: no wide-open ingress. This MUST be set to real corporate/VPN CIDRs.
variable "allowed_ingress_cidrs" {
  description = "CIDRs allowed to reach the public ALB. REQUIRED in prod - no default open."
  type        = list(string)
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
}

# ---- DR failover DNS (optional) ----
variable "hosted_zone_id" {
  description = "Route 53 hosted zone id for DR failover DNS (empty to skip)."
  type        = string
  default     = ""
}
variable "app_fqdn" {
  description = "App DNS name for failover (e.g., app.sunrise.example.com)."
  type        = string
  default     = ""
}
variable "primary_fqdn" {
  description = "Primary-region endpoint DNS."
  type        = string
  default     = ""
}
variable "dr_fqdn" {
  description = "DR-region endpoint DNS."
  type        = string
  default     = ""
}
