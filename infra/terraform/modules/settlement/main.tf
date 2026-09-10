# modules/settlement/main.tf
# ---------------------------------------------------------------------------
# Settlement modernization (Phase 1): parallel processing with Glue (Spark),
# Lambda for lightweight steps, and Transfer Family for secure file exchange
# with card networks / partners. Goal: cut settlement processing time ~half.
#
# Flow:
#   Partner/network files --(SFTP)--> Transfer Family --> S3 (inbound)
#     --> Glue Spark job (parallel settlement) --> S3 (processed)
#     --> Lambda (notify / enqueue reconciliation)
# ---------------------------------------------------------------------------

locals {
  name = "${var.project}-${var.environment}-settlement"
}

# ==== S3 buckets: inbound files, processed output, glue scripts ============
resource "aws_s3_bucket" "settlement" {
  for_each = toset(["inbound", "processed", "scripts"])
  bucket   = "${local.name}-${each.key}-${var.bucket_suffix}"
  tags     = { Name = "${local.name}-${each.key}" }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "settlement" {
  for_each = aws_s3_bucket.settlement
  bucket   = each.value.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = var.kms_key_arn
    }
    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_public_access_block" "settlement" {
  for_each                = aws_s3_bucket.settlement
  bucket                  = each.value.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# ==== Glue Spark job: parallel settlement processing =======================
resource "aws_glue_job" "settlement" {
  name     = "${local.name}-spark-job"
  role_arn = var.glue_role_arn

  glue_version      = "4.0" # Spark 3.3
  worker_type       = var.glue_worker_type
  number_of_workers = var.glue_number_of_workers

  command {
    name            = "glueetl"
    python_version  = "3"
    script_location = "s3://${aws_s3_bucket.settlement["scripts"].id}/settlement_job.py"
  }

  default_arguments = {
    "--job-language"                     = "python"
    "--enable-metrics"                   = "true"
    "--enable-continuous-cloudwatch-log" = "true"
    "--INBOUND_BUCKET"                   = aws_s3_bucket.settlement["inbound"].id
    "--PROCESSED_BUCKET"                 = aws_s3_bucket.settlement["processed"].id
  }

  # Retry once on transient failure.
  max_retries = 1
  timeout     = 120 # minutes

  tags = { Name = "${local.name}-spark-job" }
}

# ==== Transfer Family: SFTP endpoint for partner/network file exchange =====
resource "aws_transfer_server" "sftp" {
  identity_provider_type = "SERVICE_MANAGED"
  protocols              = ["SFTP"]
  endpoint_type          = "PUBLIC" # use VPC endpoint type in prod
  tags                   = { Name = "${local.name}-sftp" }
}

# ==== Lambda: post-settlement notify / enqueue reconciliation ==============
# (Deployment package is built/pushed by CI; here we wire the function shell.)
data "aws_iam_policy_document" "lambda_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "lambda" {
  name               = "${local.name}-lambda-role"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume.json
}

resource "aws_iam_role_policy_attachment" "lambda_basic" {
  role       = aws_iam_role.lambda.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}
