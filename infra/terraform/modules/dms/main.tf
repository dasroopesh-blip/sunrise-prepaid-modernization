# modules/dms/main.tf
# ---------------------------------------------------------------------------
# Database Migration Service (DMS): moves DATA from source SQL Server to
# target Aurora PostgreSQL, with full-load + change-data-capture (CDC).
#
# DMS moves DATA, not stored-proc logic (that goes to the app tier - see the
# migration docs). This module wires:
#   - a replication instance (the compute that runs migration tasks)
#   - a source endpoint (SQL Server) and target endpoint (Aurora PostgreSQL)
#   - a full-load-and-cdc task with table mappings + validation enabled
# ---------------------------------------------------------------------------

locals {
  name = "${var.project}-${var.environment}-dms"
}

# Subnet group: which subnets the replication instance runs in.
resource "aws_dms_replication_subnet_group" "this" {
  replication_subnet_group_id          = local.name
  replication_subnet_group_description = "Subnets for ${local.name}"
  subnet_ids                           = var.private_subnet_ids
  tags                                 = { Name = local.name }
}

# The replication instance (Multi-AZ for resilient long-running CDC).
resource "aws_dms_replication_instance" "this" {
  replication_instance_id     = local.name
  replication_instance_class  = var.instance_class
  allocated_storage           = var.allocated_storage
  multi_az                    = var.multi_az
  publicly_accessible         = false
  replication_subnet_group_id = aws_dms_replication_subnet_group.this.id
  vpc_security_group_ids      = [var.dms_sg_id]
  kms_key_arn                 = var.kms_key_arn
  tags                        = { Name = local.name }
}

# ==== Source endpoint: SQL Server =========================================
resource "aws_dms_endpoint" "source" {
  endpoint_id   = "${local.name}-source-mssql"
  endpoint_type = "source"
  engine_name   = "sqlserver"

  server_name   = var.source_server
  port          = 1433
  database_name = var.source_database
  username      = var.source_username
  password      = var.source_password # inject via secret/var, never hard-code

  extra_connection_attributes = "safeguardPolicy=RELY_ON_SQL_SERVER_REPLICATION_AGENT"
  tags                        = { Name = "${local.name}-source" }
}

# ==== Target endpoint: Aurora PostgreSQL ==================================
resource "aws_dms_endpoint" "target" {
  endpoint_id   = "${local.name}-target-aurora"
  endpoint_type = "target"
  engine_name   = "aurora-postgresql"

  server_name   = var.target_server
  port          = 5432
  database_name = var.target_database
  username      = var.target_username
  password      = var.target_password

  tags = { Name = "${local.name}-target" }
}

# ==== Migration task: full load + CDC + validation ========================
resource "aws_dms_replication_task" "full_load_cdc" {
  replication_task_id      = "${local.name}-fullload-cdc"
  migration_type           = "full-load-and-cdc"
  replication_instance_arn = aws_dms_replication_instance.this.replication_instance_arn
  source_endpoint_arn      = aws_dms_endpoint.source.endpoint_arn
  target_endpoint_arn      = aws_dms_endpoint.target.endpoint_arn

  # Table mappings + task settings are kept in JSON files for readability.
  table_mappings    = file("${path.module}/table-mappings.json")
  replication_task_settings = file("${path.module}/task-settings.json")

  tags = { Name = "${local.name}-fullload-cdc" }
}
