# modules/observability/main.tf
# ---------------------------------------------------------------------------
# Observability (Phase 1): CloudWatch log groups, a dashboard, alarms tied to
# the reliability objective (99.99%), and an SNS topic for alerts. X-Ray
# tracing is enabled on the app side (annotation only here).
# ---------------------------------------------------------------------------

locals {
  name = "${var.project}-${var.environment}"
}

# ==== Central log group ====================================================
resource "aws_cloudwatch_log_group" "app" {
  name              = "/${local.name}/app"
  retention_in_days = var.log_retention_days
  kms_key_id        = var.kms_key_arn
  tags              = { Name = "${local.name}-app-logs" }
}

resource "aws_cloudwatch_log_group" "settlement" {
  name              = "/${local.name}/settlement"
  retention_in_days = var.log_retention_days
  kms_key_id        = var.kms_key_arn
  tags              = { Name = "${local.name}-settlement-logs" }
}

# ==== SNS topic for alarm notifications ====================================
resource "aws_sns_topic" "alerts" {
  name              = "${local.name}-ops-alerts"
  kms_master_key_id = var.kms_key_arn
  tags              = { Name = "${local.name}-ops-alerts" }
}

resource "aws_sns_topic_subscription" "email" {
  for_each  = toset(var.alert_emails)
  topic_arn = aws_sns_topic.alerts.arn
  protocol  = "email"
  endpoint  = each.value
}

# ==== Example alarms tied to reliability ===================================
# DLQ depth > 0 means messages are failing processing -> page the team.
resource "aws_cloudwatch_metric_alarm" "recon_dlq_not_empty" {
  count               = var.recon_dlq_name == "" ? 0 : 1
  alarm_name          = "${local.name}-recon-dlq-not-empty"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "ApproximateNumberOfMessagesVisible"
  namespace           = "AWS/SQS"
  period              = 60
  statistic           = "Maximum"
  threshold           = 0
  alarm_description   = "Reconciliation DLQ has messages - processing failures."
  dimensions          = { QueueName = var.recon_dlq_name }
  alarm_actions       = [aws_sns_topic.alerts.arn]
  ok_actions          = [aws_sns_topic.alerts.arn]
}

# ==== CloudWatch dashboard =================================================
resource "aws_cloudwatch_dashboard" "main" {
  dashboard_name = "${local.name}-overview"
  dashboard_body = jsonencode({
    widgets = [
      {
        type = "text", x = 0, y = 0, width = 24, height = 2,
        properties = { markdown = "# ${upper(var.project)} ${upper(var.environment)} — Sunrise Prepaid Modernization\nReliability objective: **99.99%**. Watch DLQ depth, DMS latency, EKS health." }
      }
    ]
  })
}
