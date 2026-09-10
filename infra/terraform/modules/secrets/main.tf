# modules/secrets/main.tf
# ---------------------------------------------------------------------------
# Secrets Manager entries for database credentials and other secrets. This is
# the Phase 1 "use Secrets Manager for credentials management" deliverable.
#
# IMPORTANT: We do NOT put real passwords in Terraform code. We create the
# secret CONTAINER here; the actual value is either:
#   - generated randomly (below), or
#   - set out-of-band via the AWS console / CLI / rotation lambda.
# ---------------------------------------------------------------------------

locals {
  name = "${var.project}-${var.environment}"
}

# Generate a strong random password for the database admin (dev convenience).
resource "random_password" "db" {
  for_each         = toset(var.secret_names)
  length           = 24
  special          = true
  override_special = "!#$%&*()-_=+[]{}"
}

resource "aws_secretsmanager_secret" "this" {
  for_each    = toset(var.secret_names)
  name        = "${local.name}/${each.value}"
  description = "Credentials for ${each.value} (${local.name})"
  kms_key_id  = var.kms_key_arn
  tags        = { Name = "${local.name}-secret-${each.value}" }
}

# Store an initial JSON credential blob. Rotation should replace this later.
resource "aws_secretsmanager_secret_version" "this" {
  for_each  = aws_secretsmanager_secret.this
  secret_id = each.value.id
  secret_string = jsonencode({
    username = var.default_username
    password = random_password.db[each.key].result
  })
}
