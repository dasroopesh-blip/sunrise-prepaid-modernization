# modules/iam/main.tf
# ---------------------------------------------------------------------------
# IAM roles the platform needs. IAM = who can do what. We follow least
# privilege: each service gets its OWN role with only the permissions it needs.
#
# Roles created here:
#   - dms_role_*  : the roles AWS DMS requires (vpc management, cloudwatch, s3)
#   - glue_role   : Glue jobs (settlement processing) read/write S3 + logs
#   - app_irsa    : (optional) role for EKS pods via IRSA to read secrets
# ---------------------------------------------------------------------------

locals {
  name = "${var.project}-${var.environment}"
}

# ==== DMS service roles ====================================================
# DMS expects specifically-named roles to exist in the account. These are the
# standard three. (Names are fixed by AWS for the account-level ones.)

data "aws_iam_policy_document" "dms_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["dms.amazonaws.com"]
    }
  }
}

# Allows DMS to manage the VPC networking for the replication instance.
resource "aws_iam_role" "dms_vpc" {
  name               = "dms-vpc-role" # AWS requires this exact name
  assume_role_policy = data.aws_iam_policy_document.dms_assume.json
  tags               = { Name = "dms-vpc-role" }
}

resource "aws_iam_role_policy_attachment" "dms_vpc" {
  role       = aws_iam_role.dms_vpc.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonDMSVPCManagementRole"
}

# Allows DMS to publish logs to CloudWatch.
resource "aws_iam_role" "dms_cloudwatch" {
  name               = "dms-cloudwatch-logs-role" # AWS requires this exact name
  assume_role_policy = data.aws_iam_policy_document.dms_assume.json
  tags               = { Name = "dms-cloudwatch-logs-role" }
}

resource "aws_iam_role_policy_attachment" "dms_cloudwatch" {
  role       = aws_iam_role.dms_cloudwatch.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonDMSCloudWatchLogsRole"
}

# ==== Glue job role (settlement processing) ================================
data "aws_iam_policy_document" "glue_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["glue.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "glue" {
  name               = "${local.name}-glue-role"
  assume_role_policy = data.aws_iam_policy_document.glue_assume.json
  tags               = { Name = "${local.name}-glue-role" }
}

resource "aws_iam_role_policy_attachment" "glue_service" {
  role       = aws_iam_role.glue.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSGlueServiceRole"
}

# Scoped access to the settlement S3 bucket(s) passed in.
data "aws_iam_policy_document" "glue_s3" {
  statement {
    sid       = "SettlementBucketAccess"
    actions   = ["s3:GetObject", "s3:PutObject", "s3:ListBucket", "s3:DeleteObject"]
    resources = concat(var.settlement_bucket_arns, [for a in var.settlement_bucket_arns : "${a}/*"])
  }
  statement {
    sid       = "UseKmsForS3"
    actions   = ["kms:Decrypt", "kms:GenerateDataKey"]
    resources = var.kms_key_arns
  }
}

resource "aws_iam_role_policy" "glue_s3" {
  name   = "${local.name}-glue-s3"
  role   = aws_iam_role.glue.id
  policy = data.aws_iam_policy_document.glue_s3.json
}
