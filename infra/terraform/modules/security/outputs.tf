# modules/security/outputs.tf

output "alb_sg_id" {
  description = "ALB security group id."
  value       = aws_security_group.alb.id
}

output "app_sg_id" {
  description = "Application (EKS) security group id."
  value       = aws_security_group.app.id
}

output "database_sg_id" {
  description = "Database security group id."
  value       = aws_security_group.database.id
}

output "dms_sg_id" {
  description = "DMS security group id."
  value       = aws_security_group.dms.id
}
