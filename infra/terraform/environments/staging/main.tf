# environments/staging/main.tf
# ---------------------------------------------------------------------------
# STAGING ENVIRONMENT COMPOSITION
# Mirrors dev but with more production-like settings: HA NAT per AZ, larger
# database instance counts, and stricter defaults. Sizes stay moderate to keep
# cost sane while validating production behavior.
# ---------------------------------------------------------------------------

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
  single_nat_gateway = false # staging validates HA NAT (one per AZ)
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
  desired_size       = 3
  min_size           = 3
  max_size           = 12
}

module "messaging" {
  source      = "../../modules/messaging"
  project     = var.project
  environment = var.environment
  kms_key_arn = module.kms.key_arns["storage"]
}

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
