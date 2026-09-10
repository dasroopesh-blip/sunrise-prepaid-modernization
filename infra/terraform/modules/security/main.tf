# modules/security/main.tf
# ---------------------------------------------------------------------------
# Security groups (SGs) = virtual firewalls attached to resources. We define
# tiered SGs so traffic only flows where intended:
#   ALB  -> app (EKS)  -> database
# Each SG references the one "in front of" it, so rules stay tight.
# ---------------------------------------------------------------------------

locals {
  name = "${var.project}-${var.environment}"
}

# ---- ALB / ingress SG: accepts HTTPS from the internet --------------------
resource "aws_security_group" "alb" {
  name        = "${local.name}-alb-sg"
  description = "Public load balancer: allow HTTPS in"
  vpc_id      = var.vpc_id

  ingress {
    description = "HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = var.allowed_ingress_cidrs
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = { Name = "${local.name}-alb-sg" }
}

# ---- App (EKS) SG: accepts traffic ONLY from the ALB ----------------------
resource "aws_security_group" "app" {
  name        = "${local.name}-app-sg"
  description = "Application tier (EKS): allow from ALB only"
  vpc_id      = var.vpc_id

  ingress {
    description     = "App port from ALB"
    from_port       = var.app_port
    to_port         = var.app_port
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id] # source = the ALB SG, not a CIDR
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = { Name = "${local.name}-app-sg" }
}

# ---- Database SG: accepts traffic ONLY from the app tier ------------------
resource "aws_security_group" "database" {
  name        = "${local.name}-db-sg"
  description = "Database tier: allow SQL Server (1433) + PostgreSQL (5432) from app only"
  vpc_id      = var.vpc_id

  ingress {
    description     = "SQL Server from app"
    from_port       = 1433
    to_port         = 1433
    protocol        = "tcp"
    security_groups = [aws_security_group.app.id]
  }
  ingress {
    description     = "PostgreSQL from app"
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.app.id]
  }
  # Allow the DMS SG to reach both DB engines (migration traffic).
  ingress {
    description     = "SQL Server from DMS"
    from_port       = 1433
    to_port         = 1433
    protocol        = "tcp"
    security_groups = [aws_security_group.dms.id]
  }
  ingress {
    description     = "PostgreSQL from DMS"
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.dms.id]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = { Name = "${local.name}-db-sg" }
}

# ---- DMS SG: the migration service's network identity ---------------------
resource "aws_security_group" "dms" {
  name        = "${local.name}-dms-sg"
  description = "DMS replication instance"
  vpc_id      = var.vpc_id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = { Name = "${local.name}-dms-sg" }
}
