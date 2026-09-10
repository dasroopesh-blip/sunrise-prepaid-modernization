# modules/network/main.tf
# ---------------------------------------------------------------------------
# Creates the network foundation: a VPC spread across multiple Availability
# Zones (AZs) for high availability, with public subnets (for load balancers
# / NAT) and private subnets (for app + databases), plus VPC endpoints so
# private resources reach AWS services without traversing the internet.
# ---------------------------------------------------------------------------

# Look up which AZs are usable in this region (we don't hard-code them).
data "aws_availability_zones" "available" {
  state = "available"
}

locals {
  # Take the first N AZs (N = var.az_count) for our subnets.
  azs = slice(data.aws_availability_zones.available.names, 0, var.az_count)
  name = "${var.project}-${var.environment}"
}

# ---- VPC -----------------------------------------------------------------
resource "aws_vpc" "this" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true # let instances resolve DNS
  enable_dns_hostnames = true # give instances DNS names
  tags                 = { Name = "${local.name}-vpc" }
}

# ---- Internet Gateway (for public subnets) -------------------------------
resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id
  tags   = { Name = "${local.name}-igw" }
}

# ---- Public subnets (one per AZ) -----------------------------------------
# cidrsubnet() carves the VPC CIDR into smaller blocks automatically.
resource "aws_subnet" "public" {
  for_each                = { for idx, az in local.azs : az => idx }
  vpc_id                  = aws_vpc.this.id
  availability_zone       = each.key
  cidr_block              = cidrsubnet(var.vpc_cidr, 4, each.value)          # e.g., /20 blocks
  map_public_ip_on_launch = true
  tags = {
    Name                     = "${local.name}-public-${each.key}"
    "kubernetes.io/role/elb" = "1" # lets EKS place public load balancers here
    tier                     = "public"
  }
}

# ---- Private subnets (one per AZ) ----------------------------------------
resource "aws_subnet" "private" {
  for_each          = { for idx, az in local.azs : az => idx }
  vpc_id            = aws_vpc.this.id
  availability_zone = each.key
  # Offset by 8 so private blocks never overlap the public ones.
  cidr_block = cidrsubnet(var.vpc_cidr, 4, each.value + 8)
  tags = {
    Name                              = "${local.name}-private-${each.key}"
    "kubernetes.io/role/internal-elb" = "1" # internal load balancers for EKS
    tier                              = "private"
  }
}

# ---- NAT Gateways (let private subnets reach the internet outbound) ------
# One NAT per AZ = highly available (costs more). Set single_nat_gateway=true
# in non-prod to save money.
resource "aws_eip" "nat" {
  for_each = var.single_nat_gateway ? { (local.azs[0]) = 0 } : { for idx, az in local.azs : az => idx }
  domain   = "vpc"
  tags     = { Name = "${local.name}-nat-eip-${each.key}" }
}

resource "aws_nat_gateway" "this" {
  for_each      = aws_eip.nat
  allocation_id = each.value.id
  subnet_id     = aws_subnet.public[each.key].id
  tags          = { Name = "${local.name}-nat-${each.key}" }
  depends_on    = [aws_internet_gateway.this]
}

# ---- Route tables --------------------------------------------------------
# Public route table: default route to the Internet Gateway.
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.this.id
  }
  tags = { Name = "${local.name}-rt-public" }
}

resource "aws_route_table_association" "public" {
  for_each       = aws_subnet.public
  subnet_id      = each.value.id
  route_table_id = aws_route_table.public.id
}

# Private route tables: default route to the (AZ-local, or single) NAT.
resource "aws_route_table" "private" {
  for_each = aws_subnet.private
  vpc_id   = aws_vpc.this.id
  route {
    cidr_block = "0.0.0.0/0"
    nat_gateway_id = var.single_nat_gateway ? aws_nat_gateway.this[local.azs[0]].id : aws_nat_gateway.this[each.key].id
  }
  tags = { Name = "${local.name}-rt-private-${each.key}" }
}

resource "aws_route_table_association" "private" {
  for_each       = aws_subnet.private
  subnet_id      = each.value.id
  route_table_id = aws_route_table.private[each.key].id
}

# ---- VPC Endpoints -------------------------------------------------------
# S3 gateway endpoint: private, free, keeps S3 traffic off the internet.
resource "aws_vpc_endpoint" "s3" {
  vpc_id            = aws_vpc.this.id
  service_name      = "com.amazonaws.${var.aws_region}.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = [for rt in aws_route_table.private : rt.id]
  tags              = { Name = "${local.name}-vpce-s3" }
}

# Interface endpoints for the AWS services our workloads call privately.
resource "aws_vpc_endpoint" "interface" {
  for_each            = toset(var.interface_endpoints)
  vpc_id              = aws_vpc.this.id
  service_name        = "com.amazonaws.${var.aws_region}.${each.value}"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = [for s in aws_subnet.private : s.id]
  security_group_ids  = [aws_security_group.endpoints.id]
  private_dns_enabled = true
  tags                = { Name = "${local.name}-vpce-${each.value}" }
}

# Security group allowing HTTPS from inside the VPC to the interface endpoints.
resource "aws_security_group" "endpoints" {
  name        = "${local.name}-vpce-sg"
  description = "Allow HTTPS from within the VPC to interface endpoints"
  vpc_id      = aws_vpc.this.id

  ingress {
    description = "HTTPS from VPC"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = { Name = "${local.name}-vpce-sg" }
}
