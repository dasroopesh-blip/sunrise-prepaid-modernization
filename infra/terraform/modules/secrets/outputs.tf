# modules/secrets/outputs.tf

output "secret_arns" {
  description = "Map of logical secret name -> Secrets Manager ARN."
  value       = { for k, v in aws_secretsmanager_secret.this : k => v.arn }
}
