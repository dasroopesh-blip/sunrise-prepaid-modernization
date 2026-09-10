# modules/network/variables.tf

variable "project" {
  description = "Project name prefix."
  type        = string
}

variable "environment" {
  description = "Environment name (dev/staging/prod)."
  type        = string
}

variable "aws_region" {
  description = "Region (used to build VPC endpoint service names)."
  type        = string
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC, e.g. 10.20.0.0/16."
  type        = string
  default     = "10.20.0.0/16"
}

variable "az_count" {
  description = "Number of Availability Zones to spread subnets across (>=2 for HA)."
  type        = number
  default     = 3
  validation {
    condition     = var.az_count >= 2 && var.az_count <= 4
    error_message = "az_count must be between 2 and 4."
  }
}

variable "single_nat_gateway" {
  description = "If true, use ONE NAT gateway (cheaper, less HA) - good for dev."
  type        = bool
  default     = true
}

variable "interface_endpoints" {
  description = "AWS services to expose via private interface endpoints."
  type        = list(string)
  default = [
    "secretsmanager",
    "kms",
    "ecr.api",
    "ecr.dkr",
    "logs",
    "sts",
    "kinesis-streams",
    "sqs",
    "glue",
  ]
}
