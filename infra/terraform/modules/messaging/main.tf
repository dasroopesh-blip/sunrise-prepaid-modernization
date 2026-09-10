# modules/messaging/main.tf
# ---------------------------------------------------------------------------
# Decoupling layer (Phase 1): Kinesis for real-time alert streaming and SQS
# for reliable work queues + a reconciliation queue with a dead-letter queue.
# This breaks the tight app<->DB coupling and enables the EKS reconciliation
# service described in the strategy.
# ---------------------------------------------------------------------------

locals {
  name = "${var.project}-${var.environment}"
}

# ==== Kinesis: alert stream ================================================
resource "aws_kinesis_stream" "alerts" {
  name = "${local.name}-alerts"

  # On-demand billing = auto-scales shards with load (no manual shard math).
  stream_mode_details { stream_mode = "ON_DEMAND" }

  # Encrypt with KMS.
  encryption_type = "KMS"
  kms_key_id      = var.kms_key_arn

  tags = { Name = "${local.name}-alerts" }
}

# ==== SQS: reconciliation work queue + dead-letter queue ===================
# Dead-letter queue: messages that fail processing repeatedly land here.
resource "aws_sqs_queue" "recon_dlq" {
  name                      = "${local.name}-recon-dlq"
  message_retention_seconds = 1209600 # 14 days
  kms_master_key_id         = var.kms_key_arn
  tags                      = { Name = "${local.name}-recon-dlq" }
}

resource "aws_sqs_queue" "recon" {
  name                       = "${local.name}-recon"
  visibility_timeout_seconds = 60
  kms_master_key_id          = var.kms_key_arn

  # After 5 failed receives, send the message to the DLQ.
  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.recon_dlq.arn
    maxReceiveCount     = 5
  })

  tags = { Name = "${local.name}-recon" }
}

# ==== SQS: settlement events queue ========================================
resource "aws_sqs_queue" "settlement" {
  name                       = "${local.name}-settlement"
  visibility_timeout_seconds = 300
  kms_master_key_id          = var.kms_key_arn
  tags                       = { Name = "${local.name}-settlement" }
}
