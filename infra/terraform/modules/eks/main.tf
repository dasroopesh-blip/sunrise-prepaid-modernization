# modules/eks/main.tf
# ---------------------------------------------------------------------------
# Application tier: an Amazon EKS (Kubernetes) cluster that hosts the existing
# Java/Spring Boot Sunrise services (which absorb the stored-proc logic in
# Phase 2). Multi-AZ managed node group with autoscaling = the "scale beyond
# 30% YoY" and "eliminate manual scaling" goals.
#
# NOTE: This provisions the CLUSTER + NODE GROUP. Deploying the app workloads
# (Deployments/Services/HPA) is done with kubectl/Helm/GitOps afterwards.
# ---------------------------------------------------------------------------

locals {
  name = "${var.project}-${var.environment}-eks"
}

# ==== IAM role the EKS CONTROL PLANE assumes ==============================
data "aws_iam_policy_document" "cluster_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["eks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "cluster" {
  name               = "${local.name}-cluster-role"
  assume_role_policy = data.aws_iam_policy_document.cluster_assume.json
}

resource "aws_iam_role_policy_attachment" "cluster" {
  role       = aws_iam_role.cluster.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
}

# ==== The EKS cluster ======================================================
resource "aws_eks_cluster" "this" {
  name     = local.name
  role_arn = aws_iam_role.cluster.arn
  version  = var.kubernetes_version

  vpc_config {
    subnet_ids              = var.private_subnet_ids # nodes/pods run private
    endpoint_private_access = true
    endpoint_public_access  = true # tighten/limit in prod
    security_group_ids      = [var.app_sg_id]
  }

  # Encrypt Kubernetes secrets at rest with our KMS key.
  encryption_config {
    provider { key_arn = var.kms_key_arn }
    resources = ["secrets"]
  }

  depends_on = [aws_iam_role_policy_attachment.cluster]
  tags       = { Name = local.name }
}

# ==== IAM role the WORKER NODES assume =====================================
data "aws_iam_policy_document" "node_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "node" {
  name               = "${local.name}-node-role"
  assume_role_policy = data.aws_iam_policy_document.node_assume.json
}

# The three managed policies worker nodes need.
resource "aws_iam_role_policy_attachment" "node" {
  for_each = toset([
    "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy",
    "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy",
    "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly",
  ])
  role       = aws_iam_role.node.name
  policy_arn = each.value
}

# ==== Managed node group (autoscaling, multi-AZ) ===========================
resource "aws_eks_node_group" "this" {
  cluster_name    = aws_eks_cluster.this.name
  node_group_name = "${local.name}-ng"
  node_role_arn   = aws_iam_role.node.arn
  subnet_ids      = var.private_subnet_ids # spreads across the AZs
  instance_types  = [var.node_instance_type]

  scaling_config {
    desired_size = var.desired_size
    min_size     = var.min_size
    max_size     = var.max_size
  }

  update_config {
    max_unavailable = 1 # rolling updates keep the service up
  }

  depends_on = [aws_iam_role_policy_attachment.node]
  tags       = { Name = "${local.name}-ng" }
}
