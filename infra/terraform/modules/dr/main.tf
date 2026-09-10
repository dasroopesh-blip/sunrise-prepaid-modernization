# modules/dr/main.tf
# ---------------------------------------------------------------------------
# Disaster Recovery (active-warm, multi-region). This module provisions the
# DR-region primitives that a warm standby needs:
#   - a DR S3 bucket for replicated settlement/backups
#   - Route 53 health check + failover DNS records (primary -> DR)
#
# The DR region uses the aliased provider `aws.dr` (configured in providers.tf).
# Aurora cross-region replicas / global database are enabled on the DB module
# in a full build; here we wire the DNS failover and DR storage that tie it
# together, keeping the module focused and readable.
# ---------------------------------------------------------------------------

terraform {
  required_providers {
    aws = {
      source                = "hashicorp/aws"
      configuration_aliases = [aws.dr] # this module expects a DR-region provider
    }
  }
}

locals {
  name = "${var.project}-${var.environment}-dr"
}

# ---- DR-region S3 bucket (replication target) ----------------------------
resource "aws_s3_bucket" "dr" {
  provider = aws.dr
  bucket   = "${local.name}-${var.bucket_suffix}"
  tags     = { Name = local.name, role = "dr" }
}

resource "aws_s3_bucket_versioning" "dr" {
  provider = aws.dr
  bucket   = aws_s3_bucket.dr.id
  versioning_configuration { status = "Enabled" }
}

# ---- Route 53 failover DNS -----------------------------------------------
# Health check on the PRIMARY endpoint; if it fails, DNS points at the DR one.
resource "aws_route53_health_check" "primary" {
  count             = var.hosted_zone_id == "" ? 0 : 1
  fqdn              = var.primary_fqdn
  port              = 443
  type              = "HTTPS"
  resource_path     = var.health_check_path
  failure_threshold = 3
  request_interval  = 30
  tags              = { Name = "${local.name}-primary-hc" }
}

resource "aws_route53_record" "primary" {
  count          = var.hosted_zone_id == "" ? 0 : 1
  zone_id        = var.hosted_zone_id
  name           = var.app_fqdn
  type           = "CNAME"
  ttl            = 60
  set_identifier = "primary"
  records        = [var.primary_fqdn]

  failover_routing_policy { type = "PRIMARY" }
  health_check_id = aws_route53_health_check.primary[0].id
}

resource "aws_route53_record" "secondary" {
  count          = var.hosted_zone_id == "" ? 0 : 1
  zone_id        = var.hosted_zone_id
  name           = var.app_fqdn
  type           = "CNAME"
  ttl            = 60
  set_identifier = "secondary-dr"
  records        = [var.dr_fqdn]

  failover_routing_policy { type = "SECONDARY" }
}
