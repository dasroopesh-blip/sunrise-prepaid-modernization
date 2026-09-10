# modules/rds-sqlserver/main.tf
# ---------------------------------------------------------------------------
# Phase 2b FALLBACK database: Amazon RDS for SQL Server, Multi-AZ,
# KMS-encrypted. This is the managed lift for workloads whose stored-proc
# logic is NOT yet ready to move to the app tier / Aurora PostgreSQL.
#
# It still achieves the core goals: exit on-prem, get HA + backups + PITR,
# and beat the SQL Server 2016 end-of-support deadline - without blocking the
# whole program on the hardest-to-convert procedures.
# ---------------------------------------------------------------------------

locals {
  name = "${var.project}-${var.environment}-mssql-rds"
}

resource "aws_db_subnet_group" "this" {
  name       = local.name
  subnet_ids = var.private_subnet_ids
  tags       = { Name = local.name }
}

resource "aws_db_instance" "this" {
  identifier     = local.name
  engine         = "sqlserver-se" # Standard Edition; use -ee for Enterprise
  engine_version = var.engine_version
  instance_class = var.instance_class

  allocated_storage     = var.allocated_storage
  max_allocated_storage = var.max_allocated_storage # storage autoscaling
  storage_type          = "gp3"

  # Multi-AZ = synchronous standby in another AZ with automatic failover.
  multi_az = true

  username = var.master_username
  # RDS-managed master password (stored in Secrets Manager automatically).
  manage_master_user_password = true

  db_subnet_group_name   = aws_db_subnet_group.this.name
  vpc_security_group_ids = [var.database_sg_id]

  # KMS encryption at rest (replaces TDE).
  storage_encrypted = true
  kms_key_id        = var.kms_key_arn

  # Backups + point-in-time recovery.
  backup_retention_period = var.backup_retention_days
  backup_window           = "03:00-04:00"
  maintenance_window      = "sun:04:30-sun:05:30"

  # SQL Server requires accepting the license model.
  license_model = "license-included"

  deletion_protection = var.deletion_protection
  skip_final_snapshot = var.environment != "prod"

  tags = { Name = local.name }
}
