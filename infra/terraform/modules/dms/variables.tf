# modules/dms/variables.tf

variable "project" {
  description = "Project name prefix."
  type        = string
}

variable "environment" {
  description = "Environment name."
  type        = string
}

variable "private_subnet_ids" {
  description = "Private subnets for the replication instance (multi-AZ)."
  type        = list(string)
}

variable "dms_sg_id" {
  description = "Security group id for the DMS replication instance."
  type        = string
}

variable "kms_key_arn" {
  description = "KMS key ARN for DMS encryption."
  type        = string
}

variable "instance_class" {
  description = "DMS replication instance class."
  type        = string
  default     = "dms.c5.2xlarge"
}

variable "allocated_storage" {
  description = "Replication instance storage (GB)."
  type        = number
  default     = 100
}

variable "multi_az" {
  description = "Run the replication instance Multi-AZ (recommended for CDC)."
  type        = bool
  default     = true
}

# ---- Source (SQL Server) ----
variable "source_server" {
  description = "SQL Server hostname/IP (on-prem or EC2 AG listener)."
  type        = string
}
variable "source_database" {
  description = "Source database name."
  type        = string
}
variable "source_username" {
  description = "Source DB username (prefer injecting from Secrets Manager)."
  type        = string
}
variable "source_password" {
  description = "Source DB password (inject from Secrets Manager; never commit)."
  type        = string
  sensitive   = true
}

# ---- Target (Aurora PostgreSQL) ----
variable "target_server" {
  description = "Aurora writer endpoint."
  type        = string
}
variable "target_database" {
  description = "Target database name."
  type        = string
}
variable "target_username" {
  description = "Target DB username."
  type        = string
}
variable "target_password" {
  description = "Target DB password (inject from Secrets Manager; never commit)."
  type        = string
  sensitive   = true
}
