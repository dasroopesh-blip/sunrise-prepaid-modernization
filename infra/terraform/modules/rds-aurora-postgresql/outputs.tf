# modules/rds-aurora-postgresql/outputs.tf

output "cluster_endpoint" {
  description = "Writer endpoint (use for writes)."
  value       = aws_rds_cluster.this.endpoint
}

output "reader_endpoint" {
  description = "Reader endpoint (use for read scaling)."
  value       = aws_rds_cluster.this.reader_endpoint
}

output "cluster_arn" {
  description = "Aurora cluster ARN (DMS target)."
  value       = aws_rds_cluster.this.arn
}

output "database_name" {
  description = "Initial database name."
  value       = aws_rds_cluster.this.database_name
}

output "master_user_secret_arn" {
  description = "ARN of the RDS-managed master user secret."
  value       = try(aws_rds_cluster.this.master_user_secret[0].secret_arn, null)
}
