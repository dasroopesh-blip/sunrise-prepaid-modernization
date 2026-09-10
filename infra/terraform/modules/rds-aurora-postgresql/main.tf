# modules/rds-aurora-postgresql/main.tf
# ---------------------------------------------------------------------------
# Phase 2a TARGET database: Amazon Aurora PostgreSQL, Multi-AZ, KMS-encrypted
# (KMS replaces TDE). This is where CRUD-only workloads land after the
# stored-proc logic has moved into the Spring Boot app tier.
# ---------------------------------------------------------------------------

locals {
  name = "${var.project}-${var.environment}-aurora"
}

# Subnet group tells Aurora which (private, multi-AZ) subnets to use.
resource "aws_db_subnet_group" "this" {
  name       = local.name
  subnet_ids = var.private_subnet_ids
  tags       = { Name = local.name }
}

# The Aurora CLUSTER (storage + endpoints).
resource "aws_rds_cluster" "this" {
  cluster_identifier = local.name
  engine             = "aurora-postgresql"
  engine_version     = var.engine_version
  database_name      = var.database_name

  master_username = var.master_username
  # Password sourced from Secrets Manager (managed outside code); for dev we
  # let RDS manage the master password automatically.
  manage_master_user_password = true

  db_subnet_group_name   = aws_db_subnet_group.this.name
  vpc_security_group_ids = [var.database_sg_id]

  # Encryption at rest with our KMS key (replaces TDE).
  storage_encrypted = true
  kms_key_id        = var.kms_key_arn

  # Backups + point-in-time recovery (the on-prem system had NONE of this).
  backup_retention_period      = var.backup_retention_days
  preferred_backup_window      = "03:00-04:00"
  preferred_maintenance_window = "sun:04:30-sun:05:30"
  copy_tags_to_snapshot        = true

  deletion_protection = var.deletion_protection
  skip_final_snapshot = var.environment != "prod"

  tags = { Name = local.name }
}

# Cluster INSTANCES: one writer + N readers, each in a different AZ = Multi-AZ.
resource "aws_rds_cluster_instance" "this" {
  count              = var.instance_count
  identifier         = "${local.name}-${count.index}"
  cluster_identifier = aws_rds_cluster.this.id
  engine             = aws_rds_cluster.this.engine
  engine_version     = aws_rds_cluster.this.engine_version
  instance_class     = var.instance_class

  db_subnet_group_name = aws_db_subnet_group.this.name

  # Performance Insights helps tune the CRUD-only workload.
  performance_insights_enabled    = true
  performance_insights_kms_key_id = var.kms_key_arn

  tags = { Name = "${local.name}-${count.index}", role = count.index == 0 ? "writer" : "reader" }
}
