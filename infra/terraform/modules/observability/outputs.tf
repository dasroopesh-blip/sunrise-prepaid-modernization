# modules/observability/outputs.tf

output "alerts_topic_arn" {
  description = "SNS topic ARN for ops alerts."
  value       = aws_sns_topic.alerts.arn
}

output "app_log_group" {
  description = "Application CloudWatch log group name."
  value       = aws_cloudwatch_log_group.app.name
}

output "dashboard_name" {
  description = "CloudWatch dashboard name."
  value       = aws_cloudwatch_dashboard.main.dashboard_name
}
