# CloudWatch Log Group Outputs

output "log_group_name" {
  description = "The name of the CloudWatch log group"
  value       = aws_cloudwatch_log_group.agent_logs.name
}

output "log_group_arn" {
  description = "The ARN of the CloudWatch log group"
  value       = aws_cloudwatch_log_group.agent_logs.arn
}

output "log_group_retention_days" {
  description = "The retention period in days for the log group"
  value       = aws_cloudwatch_log_group.agent_logs.retention_in_days
}

# Dashboard Outputs

output "dashboard_name" {
  description = "The name of the CloudWatch dashboard (if created)"
  value       = var.create_dashboard ? aws_cloudwatch_dashboard.agent_dashboard[0].dashboard_name : null
}

output "dashboard_arn" {
  description = "The ARN of the CloudWatch dashboard (if created)"
  value       = var.create_dashboard ? aws_cloudwatch_dashboard.agent_dashboard[0].dashboard_arn : null
}

# Metric Filter Outputs

output "invocation_metric_filter_name" {
  description = "The name of the invocation metric filter (if enabled)"
  value       = var.enable_invocation_metric ? aws_cloudwatch_log_metric_filter.invocation_count[0].name : null
}

output "error_metric_filter_name" {
  description = "The name of the error metric filter (if enabled)"
  value       = var.enable_error_metric ? aws_cloudwatch_log_metric_filter.error_count[0].name : null
}

output "latency_metric_filter_name" {
  description = "The name of the latency metric filter (if enabled)"
  value       = var.enable_latency_metric ? aws_cloudwatch_log_metric_filter.latency[0].name : null
}

# Alarm Outputs

output "error_alarm_arn" {
  description = "The ARN of the high error rate alarm (if enabled)"
  value       = var.enable_error_alarm ? aws_cloudwatch_metric_alarm.high_error_rate[0].arn : null
}

output "latency_alarm_arn" {
  description = "The ARN of the high latency alarm (if enabled)"
  value       = var.enable_latency_alarm ? aws_cloudwatch_metric_alarm.high_latency[0].arn : null
}

output "no_invocation_alarm_arn" {
  description = "The ARN of the no invocation alarm (if enabled)"
  value       = var.enable_no_invocation_alarm ? aws_cloudwatch_metric_alarm.no_invocations[0].arn : null
}

# Subscription Filter Outputs

output "error_subscription_filter_name" {
  description = "The name of the error subscription filter (if enabled)"
  value       = var.enable_error_alerts ? aws_cloudwatch_log_subscription_filter.error_filter[0].name : null
}

# Metrics Namespace

output "custom_metrics_namespace" {
  description = "The CloudWatch namespace for custom metrics"
  value       = var.custom_metrics_namespace
}

# Monitoring Configuration Summary

output "monitoring_config" {
  description = "Summary of monitoring configuration"
  value = {
    log_group_name           = aws_cloudwatch_log_group.agent_logs.name
    log_retention_days       = aws_cloudwatch_log_group.agent_logs.retention_in_days
    dashboard_enabled        = var.create_dashboard
    invocation_metric_enabled = var.enable_invocation_metric
    error_metric_enabled     = var.enable_error_metric
    latency_metric_enabled   = var.enable_latency_metric
    error_alarm_enabled      = var.enable_error_alarm
    latency_alarm_enabled    = var.enable_latency_alarm
    metrics_namespace        = var.custom_metrics_namespace
  }
}

# CloudWatch Insights Query Examples

output "insights_query_examples" {
  description = "Example CloudWatch Insights queries for common use cases"
  value = {
    recent_errors = "fields @timestamp, @message | filter @message like /ERROR/ | sort @timestamp desc | limit 20"

    invocation_count_by_hour = "fields @timestamp | stats count() by bin(5m) | sort bin(5m) desc"

    average_latency = "fields @timestamp, latency_ms | stats avg(latency_ms), max(latency_ms), min(latency_ms) by bin(5m)"

    error_rate = "stats count(@message) as total, count(@message) filter @message like /ERROR/ as errors | eval error_rate = errors / total * 100"

    top_error_types = "fields @message | filter @message like /ERROR/ | parse @message /ERROR: (?<error_type>[^:]+)/ | stats count() by error_type | sort count() desc"
  }
}
