# modules/kms/outputs.tf

output "key_arns" {
  description = "Map of key name -> KMS key ARN (database/storage/secrets)."
  value       = { for k, v in aws_kms_key.this : k => v.arn }
}

output "key_ids" {
  description = "Map of key name -> KMS key id."
  value       = { for k, v in aws_kms_key.this : k => v.key_id }
}

output "database_key_arn" {
  description = "Convenience: the database CMK ARN (used by RDS/Aurora/EC2)."
  value       = aws_kms_key.this["database"].arn
}
