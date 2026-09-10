# bootstrap/main.tf
# ---------------------------------------------------------------------------
# ONE-TIME setup: creates the S3 bucket and DynamoDB table that hold Terraform
# remote state for all environments.
#
# This is a chicken-and-egg situation: the state backend can't store its own
# state remotely (it doesn't exist yet), so THIS stack uses LOCAL state.
# Run it once per AWS account, commit its local state file is optional.
#
# Usage:
#   cd infra/terraform/bootstrap
#   terraform init
#   terraform apply
# Then copy the outputs into environments/*/backend.tf.
# ---------------------------------------------------------------------------

terraform {
  required_version = ">= 1.5.0, < 2.0.0"
  required_providers {
    aws    = { source = "hashicorp/aws", version = "~> 5.60" }
    random = { source = "hashicorp/random", version = "~> 3.6" }
  }
}

provider "aws" {
  region = var.aws_region
}

variable "aws_region" {
  description = "Region to create the state backend in."
  type        = string
  default     = "us-east-1"
}

variable "project" {
  description = "Project name prefix for resource names."
  type        = string
  default     = "sunrise"
}

# A short random suffix keeps the S3 bucket name globally unique.
resource "random_id" "suffix" {
  byte_length = 3
}

# ---- S3 bucket for state -------------------------------------------------
resource "aws_s3_bucket" "state" {
  bucket = "${var.project}-tfstate-${random_id.suffix.hex}"

  tags = {
    project    = var.project
    purpose    = "terraform-remote-state"
    managed_by = "terraform"
  }
}

# Keep old versions of state so we can recover from mistakes.
resource "aws_s3_bucket_versioning" "state" {
  bucket = aws_s3_bucket.state.id
  versioning_configuration { status = "Enabled" }
}

# Encrypt state at rest.
resource "aws_s3_bucket_server_side_encryption_configuration" "state" {
  bucket = aws_s3_bucket.state.id
  rule {
    apply_server_side_encryption_by_default { sse_algorithm = "aws:kms" }
    bucket_key_enabled = true
  }
}

# Block ALL public access to the state bucket.
resource "aws_s3_bucket_public_access_block" "state" {
  bucket                  = aws_s3_bucket.state.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# ---- DynamoDB table for state locking ------------------------------------
resource "aws_dynamodb_table" "lock" {
  name         = "${var.project}-tflock-${random_id.suffix.hex}"
  billing_mode = "PAY_PER_REQUEST" # no capacity planning needed
  hash_key     = "LockID"          # Terraform requires exactly this attribute

  attribute {
    name = "LockID"
    type = "S"
  }

  tags = {
    project    = var.project
    purpose    = "terraform-state-lock"
    managed_by = "terraform"
  }
}

# ---- Outputs: paste these into environments/*/backend.tf -----------------
output "state_bucket_name" {
  description = "Put this in backend.tf `bucket`."
  value       = aws_s3_bucket.state.id
}

output "lock_table_name" {
  description = "Put this in backend.tf `dynamodb_table`."
  value       = aws_dynamodb_table.lock.name
}
