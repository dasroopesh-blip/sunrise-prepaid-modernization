# modules/rds-sqlserver/variables.tf

variable "project" {
  description = "Project name prefix."
  type        = string
}

variable "environment" {
  description = "Environment name."
  type        = string
}

variable "private_subnet_ids" {
  description = "Private subnets (multi-AZ) for the DB subnet group."
  type        = list(string)
}

variable "database_sg_id" {
  description = "Database security group id."
  type        = string
}

variable "kms_key_arn" {
  description = "KMS key ARN for storage encryption (replaces TDE)."
  type        = string
}

variable "engine_version" {
  description = "SQL Server engine version (e.g., 15.00 = 2019, 16.00 = 2022)."
  type        = string
  default     = "16.00.4085.2.v1"
}

variable "instance_class" {
  description = "RDS instance class."
  type        = string
  default     = "db.r6i.xlarge"
}

variable "allocated_storage" {
  description = "Initial storage (GB)."
  type        = number
  default     = 500
}

variable "max_allocated_storage" {
  description = "Storage autoscaling ceiling (GB)."
  type        = number
  default     = 2000
}

variable "master_username" {
  description = "Master username."
  type        = string
  default     = "sunrise_admin"
}

variable "backup_retention_days" {
  description = "Automated backup retention (enables PITR)."
  type        = number
  default     = 14
}

variable "deletion_protection" {
  description = "Prevent accidental deletion (true in prod)."
  type        = bool
  default     = false
}
