# modules/sqlserver-ec2-ag/main.tf
# ---------------------------------------------------------------------------
# Phase 1 HIGH AVAILABILITY: SQL Server 2019/2022 on EC2, one node per AZ,
# configured (post-provision) into an Always On Availability Group (AG).
#
# Why this (vs. jumping straight to RDS)?  It preserves SQL Server behavior
# 1:1 while adding automatic failover (10-30s) and gets us off the on-prem
# Simple-recovery, no-HA situation BEFORE SQL Server 2016 end-of-support.
#
# Terraform provisions the INFRASTRUCTURE (instances, encrypted disks, AZ
# spread). The Windows Failover Cluster + AG + Listener are configured on top
# via userdata/SSM/Ansible (out of scope for pure IaC) - see the runbook
# docs/runbooks. Node 0 is the initial primary.
# ---------------------------------------------------------------------------

locals {
  name = "${var.project}-${var.environment}-mssql"
  # Spread nodes across the provided subnets (AZs), wrapping if fewer subnets.
  node_subnets = { for n in range(var.node_count) : n => var.private_subnet_ids[n % length(var.private_subnet_ids)] }
}

# Look up the latest SQL Server on Windows AMI if the caller didn't pin one.
data "aws_ami" "sqlserver" {
  count       = var.sql_ami_id == "" ? 1 : 0
  most_recent = true
  owners      = ["amazon"]
  filter {
    name   = "name"
    values = ["Windows_Server-2022-English-Full-SQL_2022_Standard-*"]
  }
}

locals {
  ami_id = var.sql_ami_id != "" ? var.sql_ami_id : data.aws_ami.sqlserver[0].id
}

# One EC2 instance per AG node.
resource "aws_instance" "node" {
  for_each      = local.node_subnets
  ami           = local.ami_id
  instance_type = var.instance_type
  subnet_id     = each.value
  key_name      = var.key_name

  vpc_security_group_ids = [var.database_sg_id]

  # Encrypt the OS root volume with our KMS database key (replaces TDE-at-disk).
  root_block_device {
    volume_size = 100
    volume_type = "gp3"
    encrypted   = true
    kms_key_id  = var.kms_key_arn
  }

  # Enforce IMDSv2 (security best practice).
  metadata_options {
    http_tokens   = "required"
    http_endpoint = "enabled"
  }

  tags = {
    Name = "${local.name}-node-${each.key}"
    role = each.key == 0 ? "ag-primary-initial" : "ag-secondary"
  }
}

# Dedicated encrypted data volume per node (SQL data/log files).
resource "aws_ebs_volume" "data" {
  for_each          = local.node_subnets
  availability_zone = aws_instance.node[each.key].availability_zone
  size              = var.data_volume_gb
  type              = "gp3"
  encrypted         = true
  kms_key_id        = var.kms_key_arn
  tags              = { Name = "${local.name}-data-${each.key}" }
}

resource "aws_volume_attachment" "data" {
  for_each    = local.node_subnets
  device_name = "/dev/xvdf"
  volume_id   = aws_ebs_volume.data[each.key].id
  instance_id = aws_instance.node[each.key].id
}
