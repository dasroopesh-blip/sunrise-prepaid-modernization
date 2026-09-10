# environments/prod/main.tf
# ---------------------------------------------------------------------------
# PRODUCTION ENVIRONMENT COMPOSITION
# Production-hardened: HA NAT per AZ, deletion protection on databases, larger
# instance sizes, more DB replicas, longer backup retention, and DR failover
# DNS wired. Ingress CIDRs are REQUIRED (no wide-open default).
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
  single_nat_gateway = false # prod: one NAT per AZ (highly available)
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
  allowed_ingress_cidrs = var.allowed_ingress_cidrs # REQUIRED; no open default
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
  instance_type      = "r6i.4xlarge" # larger for prod
  data_volume_gb     = 1000
}

module "eks" {
  source             = "../../modules/eks"
  project            = var.project
  environment        = var.environment
  private_subnet_ids = module.network.private_subnet_ids
  app_sg_id          = module.security.app_sg_id
  kms_key_arn        = module.kms.key_arns["secrets"]
  node_instance_type = "m6i.2xlarge"
  desired_size       = 6
  min_size           = 6
  max_size           = 24
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
  source                 = "../../modules/settlement"
  project                = var.project
  environment            = var.environment
  kms_key_arn            = module.kms.key_arns["storage"]
  glue_role_arn          = module.iam.glue_role_arn
  bucket_suffix          = local.bucket_suffix
  glue_number_of_workers = 20 # more parallelism for prod settlement volume
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
  source                = "../../modules/rds-aurora-postgresql"
  project               = var.project
  environment           = var.environment
  private_subnet_ids    = module.network.private_subnet_ids
  database_sg_id        = module.security.database_sg_id
  kms_key_arn           = module.kms.database_key_arn
  instance_class        = "db.r6g.2xlarge"
  instance_count        = 3  # 1 writer + 2 readers across AZs
  backup_retention_days = 35 # longer retention for prod
  deletion_protection   = true
}

module "rds_sqlserver" {
  source                = "../../modules/rds-sqlserver"
  project               = var.project
  environment           = var.environment
  private_subnet_ids    = module.network.private_subnet_ids
  database_sg_id        = module.security.database_sg_id
  kms_key_arn           = module.kms.database_key_arn
  instance_class        = "db.r6i.2xlarge"
  allocated_storage     = 1000
  max_allocated_storage = 4000
  backup_retention_days = 35
  deletion_protection   = true
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

  # Wire DR failover DNS in prod (skipped automatically if hosted_zone_id empty).
  hosted_zone_id = var.hosted_zone_id
  app_fqdn       = var.app_fqdn
  primary_fqdn   = var.primary_fqdn
  dr_fqdn        = var.dr_fqdn

  providers = {
    aws.dr = aws.dr
  }
}
