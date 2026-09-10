# modules/network/outputs.tf

output "vpc_id" {
  description = "The VPC id."
  value       = aws_vpc.this.id
}

output "vpc_cidr" {
  description = "The VPC CIDR block."
  value       = aws_vpc.this.cidr_block
}

output "public_subnet_ids" {
  description = "List of public subnet ids."
  value       = [for s in aws_subnet.public : s.id]
}

output "private_subnet_ids" {
  description = "List of private subnet ids (app + databases live here)."
  value       = [for s in aws_subnet.private : s.id]
}

output "availability_zones" {
  description = "AZs in use."
  value       = local.azs
}
