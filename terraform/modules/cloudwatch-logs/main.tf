# CloudWatch Logs Module for Monitoring
# This module creates and configures CloudWatch log groups for the agent

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 6.24.0"
    }
  }
}

# Get current AWS account ID and region
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

# Generate log group name
locals {
  log_group_name = "/aws/${var.log_group_prefix}/${var.project_name}-${var.environment}"
}

# CloudWatch Log Group
resource "aws_cloudwatch_log_group" "agent_logs" {
  name              = local.log_group_name
  retention_in_days = var.retention_in_days

  kms_key_id = var.kms_key_id

  tags = merge(
    var.tags,
    {
      Name        = local.log_group_name
      Environment = var.environment
      Purpose     = "Agent execution logs"
    }
  )
}

# Subscription filter for errors (optional)
resource "aws_cloudwatch_log_subscription_filter" "error_filter" {
  count = var.enable_error_alerts ? 1 : 0

  name            = "${var.project_name}-${var.environment}-errors"
  log_group_name  = aws_cloudwatch_log_group.agent_logs.name
  filter_pattern  = var.error_filter_pattern
  destination_arn = var.error_destination_arn

  depends_on = [aws_cloudwatch_log_group.agent_logs]
}

# Metric filter for tracking invocations
resource "aws_cloudwatch_log_metric_filter" "invocation_count" {
  count = var.enable_invocation_metric ? 1 : 0

  name           = "${var.project_name}-${var.environment}-invocations"
  log_group_name = aws_cloudwatch_log_group.agent_logs.name
  pattern        = var.invocation_filter_pattern

  metric_transformation {
    name      = "AgentInvocations"
    namespace = var.custom_metrics_namespace
    value     = "1"
    unit      = "Count"
  }

  depends_on = [aws_cloudwatch_log_group.agent_logs]
}

# Metric filter for tracking errors
resource "aws_cloudwatch_log_metric_filter" "error_count" {
  count = var.enable_error_metric ? 1 : 0

  name           = "${var.project_name}-${var.environment}-errors"
  log_group_name = aws_cloudwatch_log_group.agent_logs.name
  pattern        = var.error_filter_pattern

  metric_transformation {
    name      = "AgentErrors"
    namespace = var.custom_metrics_namespace
    value     = "1"
    unit      = "Count"
  }

  depends_on = [aws_cloudwatch_log_group.agent_logs]
}

# Metric filter for tracking latency
resource "aws_cloudwatch_log_metric_filter" "latency" {
  count = var.enable_latency_metric ? 1 : 0

  name           = "${var.project_name}-${var.environment}-latency"
  log_group_name = aws_cloudwatch_log_group.agent_logs.name
  pattern        = var.latency_filter_pattern

  metric_transformation {
    name      = "AgentLatency"
    namespace = var.custom_metrics_namespace
    value     = "$latency"
    unit      = "Milliseconds"
  }

  depends_on = [aws_cloudwatch_log_group.agent_logs]
}

# CloudWatch Dashboard
resource "aws_cloudwatch_dashboard" "agent_dashboard" {
  count = var.create_dashboard ? 1 : 0

  dashboard_name = "${var.project_name}-${var.environment}-agent"

  dashboard_body = jsonencode({
    widgets = [
      {
        type = "metric"
        properties = {
          title   = "Agent Invocations"
          metrics = [[var.custom_metrics_namespace, "AgentInvocations", { stat = "Sum", period = 300 }]]
          region  = data.aws_region.current.id
          period  = 300
        }
      },
      {
        type = "metric"
        properties = {
          title = "Agent Errors"
          metrics = [[var.custom_metrics_namespace, "AgentErrors", { stat = "Sum", period = 300 }]]
          region = data.aws_region.current.id
          period = 300
          yAxis = {
            left = {
              min = 0
            }
          }
        }
      },
      {
        type = "metric"
        properties = {
          title = "Agent Latency"
          metrics = [
            [var.custom_metrics_namespace, "AgentLatency", { stat = "Average" }],
            ["...", { stat = "p50" }],
            ["...", { stat = "p99" }]
          ]
          region = data.aws_region.current.id
          period = 300
          yAxis = {
            left = {
              label = "Milliseconds"
            }
          }
        }
      },
      {
        type = "log"
        properties = {
          title  = "Recent Agent Logs"
          query  = "SOURCE '${local.log_group_name}' | fields @timestamp, @message | sort @timestamp desc | limit 20"
          region = data.aws_region.current.id
        }
      }
    ]
  })
}

# CloudWatch Alarms

# Alarm for high error rate
resource "aws_cloudwatch_metric_alarm" "high_error_rate" {
  count = var.enable_error_alarm ? 1 : 0

  alarm_name          = "${var.project_name}-${var.environment}-high-error-rate"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = var.error_alarm_evaluation_periods
  metric_name         = "AgentErrors"
  namespace           = var.custom_metrics_namespace
  period              = var.error_alarm_period
  statistic           = "Sum"
  threshold           = var.error_alarm_threshold
  alarm_description   = "Alert when agent error rate exceeds threshold"
  alarm_actions       = var.alarm_actions
  ok_actions          = var.ok_actions

  dimensions = {
    Environment = var.environment
    Project     = var.project_name
  }

  tags = var.tags
}

# Alarm for high latency
resource "aws_cloudwatch_metric_alarm" "high_latency" {
  count = var.enable_latency_alarm ? 1 : 0

  alarm_name          = "${var.project_name}-${var.environment}-high-latency"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = var.latency_alarm_evaluation_periods
  metric_name         = "AgentLatency"
  namespace           = var.custom_metrics_namespace
  period              = var.latency_alarm_period
  statistic           = "Average"
  threshold           = var.latency_alarm_threshold_ms
  alarm_description   = "Alert when agent latency exceeds threshold"
  alarm_actions       = var.alarm_actions
  ok_actions          = var.ok_actions

  dimensions = {
    Environment = var.environment
    Project     = var.project_name
  }

  tags = var.tags
}

# Alarm for no invocations (dead agent)
resource "aws_cloudwatch_metric_alarm" "no_invocations" {
  count = var.enable_no_invocation_alarm ? 1 : 0

  alarm_name          = "${var.project_name}-${var.environment}-no-invocations"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = var.no_invocation_alarm_evaluation_periods
  metric_name         = "AgentInvocations"
  namespace           = var.custom_metrics_namespace
  period              = var.no_invocation_alarm_period
  statistic           = "Sum"
  threshold           = 1
  alarm_description   = "Alert when agent has no invocations (potential issue)"
  alarm_actions       = var.alarm_actions
  ok_actions          = var.ok_actions
  treat_missing_data  = "breaching"

  dimensions = {
    Environment = var.environment
    Project     = var.project_name
  }

  tags = var.tags
}
