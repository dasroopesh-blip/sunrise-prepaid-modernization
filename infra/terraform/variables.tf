# variables.tf
# ---------------------------------------------------------------------------
# Common variables shared by the root/provider config. Environments also
# declare these (see environments/dev/variables.tf). Kept here as the
# canonical descriptions.
# ---------------------------------------------------------------------------

variable "project" {
  description = "Project name prefix used in resource names and tags."
  type        = string
  default     = "sunrise"
}

variable "environment" {
  description = "Environment name: dev | staging | prod."
  type        = string
  default     = "dev"
}

variable "aws_region" {
  description = "Primary AWS region."
  type        = string
  default     = "us-east-1"
}

variable "dr_region" {
  description = "Disaster-recovery (secondary) AWS region."
  type        = string
  default     = "us-west-2"
}
