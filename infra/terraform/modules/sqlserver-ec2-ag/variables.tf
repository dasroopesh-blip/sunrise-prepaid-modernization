# modules/sqlserver-ec2-ag/variables.tf

variable "project" {
  description = "Project name prefix."
  type        = string
}

variable "environment" {
  description = "Environment name."
  type        = string
}

variable "private_subnet_ids" {
  description = "Private subnets (one node per AZ for the AG)."
  type        = list(string)
}

variable "database_sg_id" {
  description = "Security group id for the database tier."
  type        = string
}

variable "kms_key_arn" {
  description = "KMS key ARN for EBS volume encryption."
  type        = string
}

variable "instance_type" {
  description = "EC2 instance type for each AG node."
  type        = string
  default     = "r6i.2xlarge" # memory-optimized suits SQL Server
}

variable "node_count" {
  description = "Number of AG nodes (>=2 for HA; 2 = primary + secondary)."
  type        = number
  default     = 2
}

variable "data_volume_gb" {
  description = "Size of the data EBS volume per node."
  type        = number
  default     = 500
}

variable "sql_ami_id" {
  description = "AMI id for SQL Server on Windows (leave empty to auto-lookup latest)."
  type        = string
  default     = ""
}

variable "key_name" {
  description = "EC2 key pair name for admin access (optional)."
  type        = string
  default     = null
}
