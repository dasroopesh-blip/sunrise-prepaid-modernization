# modules/settlement/outputs.tf

output "bucket_ids" {
  description = "Map of settlement bucket role -> bucket name."
  value       = { for k, v in aws_s3_bucket.settlement : k => v.id }
}

output "bucket_arns" {
  description = "List of settlement bucket ARNs (pass to IAM/Glue)."
  value       = [for b in aws_s3_bucket.settlement : b.arn]
}

output "glue_job_name" {
  description = "Name of the Glue settlement job."
  value       = aws_glue_job.settlement.name
}

output "sftp_endpoint_id" {
  description = "Transfer Family SFTP server id."
  value       = aws_transfer_server.sftp.id
}
