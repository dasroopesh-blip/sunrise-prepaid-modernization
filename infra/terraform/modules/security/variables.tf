# modules/security/variables.tf

variable "project" {
  description = "Project name prefix."
  type        = string
}

variable "environment" {
  description = "Environment name."
  type        = string
}

variable "vpc_id" {
  description = "VPC id the security groups belong to."
  type        = string
}

variable "app_port" {
  description = "Port the Spring Boot app listens on."
  type        = number
  default     = 8080
}

variable "allowed_ingress_cidrs" {
  description = "CIDRs allowed to reach the public ALB (lock down in prod!)."
  type        = list(string)
  default     = ["0.0.0.0/0"]
}
