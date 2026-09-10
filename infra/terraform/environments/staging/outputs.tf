# environments/staging/outputs.tf

output "vpc_id" {
  value       = module.network.vpc_id
  description = "VPC id."
}

output "eks_cluster_name" {
  value       = module.eks.cluster_name
  description = "EKS cluster name."
}

output "aurora_writer_endpoint" {
  value       = module.aurora.cluster_endpoint
  description = "Aurora PostgreSQL writer endpoint."
}

output "rds_sqlserver_endpoint" {
  value       = module.rds_sqlserver.endpoint
  description = "RDS SQL Server endpoint (Phase 2b)."
}

output "dms_task_arn" {
  value       = module.dms.task_arn
  description = "DMS full-load + CDC task ARN."
}
