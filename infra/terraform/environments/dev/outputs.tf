# environments/dev/outputs.tf
# Handy values surfaced after `terraform apply`.

output "vpc_id" {
  value       = module.network.vpc_id
  description = "VPC id."
}

output "eks_cluster_name" {
  value       = module.eks.cluster_name
  description = "EKS cluster name (configure kubectl against this)."
}

output "aurora_writer_endpoint" {
  value       = module.aurora.cluster_endpoint
  description = "Aurora PostgreSQL writer endpoint."
}

output "aurora_reader_endpoint" {
  value       = module.aurora.reader_endpoint
  description = "Aurora PostgreSQL reader endpoint."
}

output "rds_sqlserver_endpoint" {
  value       = module.rds_sqlserver.endpoint
  description = "RDS SQL Server endpoint (Phase 2b)."
}

output "sqlserver_ag_node_ips" {
  value       = module.sqlserver_ag.node_private_ips
  description = "SQL Server Always On AG node private IPs (Phase 1)."
}

output "dms_task_arn" {
  value       = module.dms.task_arn
  description = "DMS full-load + CDC task ARN."
}

output "settlement_buckets" {
  value       = module.settlement.bucket_ids
  description = "Settlement S3 buckets."
}

output "ops_alerts_topic" {
  value       = module.observability.alerts_topic_arn
  description = "SNS topic for ops alerts."
}
