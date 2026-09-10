# modules/dms/outputs.tf

output "replication_instance_arn" {
  description = "DMS replication instance ARN."
  value       = aws_dms_replication_instance.this.replication_instance_arn
}

output "task_arn" {
  description = "Full-load + CDC task ARN."
  value       = aws_dms_replication_task.full_load_cdc.replication_task_arn
}

output "source_endpoint_arn" {
  description = "SQL Server source endpoint ARN."
  value       = aws_dms_endpoint.source.endpoint_arn
}

output "target_endpoint_arn" {
  description = "Aurora PostgreSQL target endpoint ARN."
  value       = aws_dms_endpoint.target.endpoint_arn
}
