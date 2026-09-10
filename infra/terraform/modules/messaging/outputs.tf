# modules/messaging/outputs.tf

output "alerts_stream_arn" {
  description = "Kinesis alerts stream ARN."
  value       = aws_kinesis_stream.alerts.arn
}

output "recon_queue_url" {
  description = "SQS reconciliation queue URL."
  value       = aws_sqs_queue.recon.id
}

output "recon_queue_arn" {
  description = "SQS reconciliation queue ARN."
  value       = aws_sqs_queue.recon.arn
}

output "settlement_queue_url" {
  description = "SQS settlement queue URL."
  value       = aws_sqs_queue.settlement.id
}
