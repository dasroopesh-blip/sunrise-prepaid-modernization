# modules/eks/variables.tf

variable "project" {
  description = "Project name prefix."
  type        = string
}

variable "environment" {
  description = "Environment name."
  type        = string
}

variable "private_subnet_ids" {
  description = "Private subnets for the cluster/nodes (multi-AZ)."
  type        = list(string)
}

variable "app_sg_id" {
  description = "Security group id for the app tier."
  type        = string
}

variable "kms_key_arn" {
  description = "KMS key ARN to encrypt Kubernetes secrets."
  type        = string
}

variable "kubernetes_version" {
  description = "EKS Kubernetes version."
  type        = string
  default     = "1.30"
}

variable "node_instance_type" {
  description = "EC2 instance type for worker nodes."
  type        = string
  default     = "m6i.large"
}

variable "desired_size" {
  description = "Desired worker node count."
  type        = number
  default     = 3
}

variable "min_size" {
  description = "Minimum worker node count."
  type        = number
  default     = 3
}

variable "max_size" {
  description = "Maximum worker node count (autoscaling ceiling)."
  type        = number
  default     = 10
}
