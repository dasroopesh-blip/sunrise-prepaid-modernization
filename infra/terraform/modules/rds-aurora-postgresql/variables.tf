# modules/rds-aurora-postgresql/variables.tf

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
  description = "Aurora PostgreSQL engine version."
  type        = string
  default     = "15.4"
}

variable "database_name" {
  description = "Initial database name."
  type        = string
  default     = "sunrise"
}

variable "master_username" {
  description = "Master username."
  type        = string
  default     = "sunrise_admin"
}

variable "instance_class" {
  description = "Aurora instance class."
  type        = string
  default     = "db.r6g.xlarge"
}

variable "instance_count" {
  description = "Number of instances (1 writer + readers). >=2 for Multi-AZ."
  type        = number
  default     = 2
}

variable "backup_retention_days" {
  description = "Automated backup retention (enables point-in-time recovery)."
  type        = number
  default     = 14
}

variable "deletion_protection" {
  description = "Prevent accidental deletion (true in prod)."
  type        = bool
  default     = false
}
