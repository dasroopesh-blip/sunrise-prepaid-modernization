# modules/kms/main.tf
# ---------------------------------------------------------------------------
# Customer-managed KMS keys (CMKs) used to encrypt data at rest across the
# platform. In Phase 2 these KMS keys REPLACE SQL Server TDE.
#
# We create one key per data domain so access can be scoped independently:
#   - database (Aurora/RDS/EC2 SQL Server volumes + backups)
#   - storage  (S3 buckets: settlement files, logs)
#   - secrets  (Secrets Manager)
# Each key gets a friendly alias so humans/tools can reference it by name.
# ---------------------------------------------------------------------------

locals {
  name = "${var.project}-${var.environment}"
  keys = toset(["database", "storage", "secrets"])
}

# Identity of the caller (account id) for the key policy.
data "aws_caller_identity" "current" {}

resource "aws_kms_key" "this" {
  for_each                = local.keys
  description             = "${local.name} ${each.key} encryption key (replaces TDE for database)"
  enable_key_rotation     = true # automatic annual key rotation
  deletion_window_in_days = 30
  multi_region            = true # allows DR region replicas of the key

  # Key policy: root account has admin; a real setup would scope down further.
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid       = "EnableRootAccountAdmin"
      Effect    = "Allow"
      Principal = { AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root" }
      Action    = "kms:*"
      Resource  = "*"
    }]
  })

  tags = { Name = "${local.name}-kms-${each.key}" }
}

resource "aws_kms_alias" "this" {
  for_each      = local.keys
  name          = "alias/${local.name}-${each.key}"
  target_key_id = aws_kms_key.this[each.key].key_id
}
