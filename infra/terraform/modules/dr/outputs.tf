# modules/dr/outputs.tf

output "dr_bucket_id" {
  description = "DR-region S3 bucket name."
  value       = aws_s3_bucket.dr.id
}

output "failover_dns" {
  description = "The app FQDN with Route 53 failover (empty if DNS skipped)."
  value       = var.app_fqdn
}
