# environments/dev/main.tf
# ---------------------------------------------------------------------------
# DEV ENVIRONMENT COMPOSITION
# This is where the reusable modules are wired together into a real, deployable
# environment. Read top-to-bottom: foundation first, then Phase 1, then Phase 2.
# Each module block passes environment-specific values and consumes other
# modules' outputs (e.g., module.network.private_subnet_ids).
# ---------------------------------------------------------------------------

# A short random suffix used to make globally-unique S3 bucket names.
resource "random_id" "suffix" {
  byte_length = 3
}

locals {
  bucket_suffix = random_id.suffix.hex
}

# ===========================================================================
# FOUNDATION
# ===========================================================================

module "network" {
  source             = "../../modules/network"
  project            = var.project
  environment        = var.environment
  aws_region         = var.aws_region
  vpc_cidr           = var.vpc_cidr
  az_count           = var.az_count
  single_nat_gateway = true # cheaper for dev
}

module "kms" {
  source      = "../../modules/kms"
  project     = var.project
  environment = var.environment
}

module "security" {
  source                = "../../modules/security"
  project               = var.project
  environment           = var.environment
  vpc_id                = module.network.vpc_id
  allowed_ingress_cidrs = var.allowed_ingress_cidrs
}

module "secrets" {
  source      = "../../modules/secrets"
  project     = var.project
  environment = var.environment
  kms_key_arn = module.kms.key_arns["secrets"]
}

# ===========================================================================
# PHASE 1 — MODERNIZE
# ===========================================================================

module "sqlserver_ag" {
  source             = "../../modules/sqlserver-ec2-ag"
  project            = var.project
  environment        = var.environment
  private_subnet_ids = module.network.private_subnet_ids
  database_sg_id     = module.security.database_sg_id
  kms_key_arn        = module.kms.database_key_arn
  node_count         = 2
}

module "eks" {
  source             = "../../modules/eks"
  project            = var.project
  environment        = var.environment
  private_subnet_ids = module.network.private_subnet_ids
  app_sg_id          = module.security.app_sg_id
  kms_key_arn        = module.kms.key_arns["secrets"]
}

module "messaging" {
  source      = "../../modules/messaging"
  project     = var.project
  environment = var.environment
  kms_key_arn = module.kms.key_arns["storage"]
}

# IAM depends on the settlement bucket ARNs, but settlement's Glue job depends
# on the IAM role -> we break the cycle by creating IAM with the KMS key and
# a KNOWN bucket name pattern, and settlement consumes the role. To keep this
# simple and acyclic in dev, IAM grants access by bucket-name prefix.
module "iam" {
  source                 = "../../modules/iam"
  project                = var.project
  environment            = var.environment
  kms_key_arns           = [module.kms.key_arns["storage"]]
  settlement_bucket_arns = ["arn:aws:s3:::${var.project}-${var.environment}-settlement-*"]
}

module "settlement" {
  source        = "../../modules/settlement"
  project       = var.project
  environment   = var.environment
  kms_key_arn   = module.kms.key_arns["storage"]
  glue_role_arn = module.iam.glue_role_arn
  bucket_suffix = local.bucket_suffix
}

module "observability" {
  source         = "../../modules/observability"
  project        = var.project
  environment    = var.environment
  kms_key_arn    = module.kms.key_arns["storage"]
  alert_emails   = var.alert_emails
  recon_dlq_name = "${var.project}-${var.environment}-recon-dlq"
}

# ===========================================================================
# PHASE 2 — RE-ARCHITECT (target databases + migration)
# ===========================================================================

module "aurora" {
  source             = "../../modules/rds-aurora-postgresql"
  project            = var.project
  environment        = var.environment
  private_subnet_ids = module.network.private_subnet_ids
  database_sg_id     = module.security.database_sg_id
  kms_key_arn        = module.kms.database_key_arn
  instance_count     = 2
}

module "rds_sqlserver" {
  source             = "../../modules/rds-sqlserver"
  project            = var.project
  environment        = var.environment
  private_subnet_ids = module.network.private_subnet_ids
  database_sg_id     = module.security.database_sg_id
  kms_key_arn        = module.kms.database_key_arn
}

# DMS is only useful once source/target are reachable. The source points at
# the EC2 AG listener (or on-prem via VPN); target is the Aurora writer.
# Passwords are injected via tfvars/CI from Secrets Manager - never committed.
module "dms" {
  source             = "../../modules/dms"
  project            = var.project
  environment        = var.environment
  private_subnet_ids = module.network.private_subnet_ids
  dms_sg_id          = module.security.dms_sg_id
  kms_key_arn        = module.kms.database_key_arn

  source_server   = var.dms_source_server
  source_database = var.dms_source_database
  source_username = var.dms_source_username
  source_password = var.dms_source_password

  target_server   = module.aurora.cluster_endpoint
  target_database = module.aurora.database_name
  target_username = var.dms_target_username
  target_password = var.dms_target_password
}

module "dr" {
  source        = "../../modules/dr"
  project       = var.project
  environment   = var.environment
  bucket_suffix = local.bucket_suffix
  providers = {
    aws.dr = aws.dr
  }
}
