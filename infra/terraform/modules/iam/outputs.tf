# modules/iam/outputs.tf

output "dms_vpc_role_arn" {
  description = "ARN of the DMS VPC management role."
  value       = aws_iam_role.dms_vpc.arn
}

output "glue_role_arn" {
  description = "ARN of the Glue job execution role."
  value       = aws_iam_role.glue.arn
}
