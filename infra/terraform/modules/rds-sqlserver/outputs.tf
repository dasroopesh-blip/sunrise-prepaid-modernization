# modules/rds-sqlserver/outputs.tf

output "endpoint" {
  description = "RDS SQL Server endpoint (host:port)."
  value       = aws_db_instance.this.endpoint
}

output "address" {
  description = "RDS SQL Server hostname."
  value       = aws_db_instance.this.address
}

output "arn" {
  description = "RDS SQL Server instance ARN (DMS target)."
  value       = aws_db_instance.this.arn
}
