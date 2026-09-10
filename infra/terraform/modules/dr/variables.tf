# modules/dr/variables.tf

variable "project" {
  description = "Project name prefix."
  type        = string
}

variable "environment" {
  description = "Environment name."
  type        = string
}

variable "bucket_suffix" {
  description = "Unique suffix for the DR S3 bucket name."
  type        = string
}

variable "hosted_zone_id" {
  description = "Route 53 hosted zone id (leave empty to skip DNS failover)."
  type        = string
  default     = ""
}

variable "app_fqdn" {
  description = "The application DNS name users hit (e.g., app.sunrise.example.com)."
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

variable "health_check_path" {
  description = "HTTP path used for the primary health check."
  type        = string
  default     = "/actuator/health" # Spring Boot health endpoint
}
