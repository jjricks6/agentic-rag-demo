# CloudWatch Logs Module

Terraform module for creating and configuring CloudWatch log groups, metric filters, alarms, and dashboards for monitoring Bedrock agents.

## Overview

This module provides comprehensive observability for your agent:
- **Log Groups**: Centralized log storage with configurable retention
- **Metric Filters**: Extract metrics from logs (invocations, errors, latency)
- **CloudWatch Alarms**: Automated alerting for errors, latency, and availability
- **Dashboard**: Visual monitoring interface
- **Insights Queries**: Pre-built queries for common analysis

## Features

- ✅ **Automatic Metric Extraction**: Turn logs into actionable metrics
- ✅ **Pre-configured Alarms**: Catch errors and performance issues early
- ✅ **Visual Dashboard**: Real-time agent monitoring
- ✅ **Cost Optimized**: Configurable retention periods
- ✅ **Security**: Optional KMS encryption for logs

## Usage

### Basic Usage

```hcl
module "cloudwatch_logs" {
  source = "../../modules/cloudwatch-logs"

  project_name = "agentic-rag-demo"
  environment  = "dev"

  # Log retention
  retention_in_days = 7

  tags = {
    Project = "agentic-rag-demo"
    Team    = "AI/ML"
  }
}
```

### Production Configuration with Alarms

```hcl
# SNS topic for alerts
resource "aws_sns_topic" "alerts" {
  name = "agentic-rag-demo-prod-alerts"
}

resource "aws_sns_topic_subscription" "email_alert" {
  topic_arn = aws_sns_topic.alerts.arn
  protocol  = "email"
  endpoint  = "devops@example.com"
}

module "cloudwatch_logs" {
  source = "../../modules/cloudwatch-logs"

  project_name = "agentic-rag-demo"
  environment  = "prod"

  # Log configuration
  log_group_prefix  = "bedrock"
  retention_in_days = 30
  kms_key_id        = aws_kms_key.logs.id

  # Metrics
  enable_invocation_metric = true
  enable_error_metric      = true
  enable_latency_metric    = true
  custom_metrics_namespace = "AgenticRAG/Production"

  # Alarms
  enable_error_alarm             = true
  error_alarm_threshold          = 10
  error_alarm_evaluation_periods = 2
  error_alarm_period             = 300

  enable_latency_alarm             = true
  latency_alarm_threshold_ms       = 3000
  latency_alarm_evaluation_periods = 2
  latency_alarm_period             = 300

  enable_no_invocation_alarm             = true
  no_invocation_alarm_evaluation_periods = 3
  no_invocation_alarm_period             = 3600

  # Notifications
  alarm_actions = [aws_sns_topic.alerts.arn]
  ok_actions    = [aws_sns_topic.alerts.arn]

  # Dashboard
  create_dashboard = true

  tags = {
    Project     = "agentic-rag-demo"
    Environment = "prod"
    Criticality = "high"
  }
}
```

### With Error Subscription Filter

```hcl
# Lambda function to handle error alerts
resource "aws_lambda_function" "error_handler" {
  filename      = "error_handler.zip"
  function_name = "agentic-rag-demo-error-handler"
  role          = aws_iam_role.lambda_role.arn
  handler       = "index.handler"
  runtime       = "python3.11"
}

resource "aws_lambda_permission" "cloudwatch_logs" {
  statement_id  = "AllowExecutionFromCloudWatchLogs"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.error_handler.function_name
  principal     = "logs.amazonaws.com"
  source_arn    = "${module.cloudwatch_logs.log_group_arn}:*"
}

module "cloudwatch_logs" {
  source = "../../modules/cloudwatch-logs"

  project_name = "agentic-rag-demo"
  environment  = "prod"

  # Error alerting
  enable_error_alerts   = true
  error_destination_arn = aws_lambda_function.error_handler.arn

  tags = {
    Project = "agentic-rag-demo"
  }
}
```

## Requirements

| Name | Version |
|------|---------|
| terraform | >= 1.5.0 |
| aws | ~> 5.0 |

## Providers

| Name | Version |
|------|---------|
| aws | ~> 5.0 |

## Inputs

### Required Inputs

| Name | Description | Type | Default |
|------|-------------|------|---------|
| project_name | Name of the project | `string` | n/a |
| environment | Environment name | `string` | n/a |

### Optional Inputs - Log Configuration

| Name | Description | Type | Default |
|------|-------------|------|---------|
| log_group_prefix | Log group prefix | `string` | `"bedrock"` |
| retention_in_days | Log retention period | `number` | `7` |
| kms_key_id | KMS key for encryption | `string` | `null` |

### Optional Inputs - Metrics

| Name | Description | Type | Default |
|------|-------------|------|---------|
| enable_invocation_metric | Track invocations | `bool` | `true` |
| enable_error_metric | Track errors | `bool` | `true` |
| enable_latency_metric | Track latency | `bool` | `true` |
| custom_metrics_namespace | CloudWatch namespace | `string` | `"AgenticRAG"` |

### Optional Inputs - Alarms

| Name | Description | Type | Default |
|------|-------------|------|---------|
| enable_error_alarm | Enable error alarm | `bool` | `true` |
| error_alarm_threshold | Error count threshold | `number` | `5` |
| enable_latency_alarm | Enable latency alarm | `bool` | `true` |
| latency_alarm_threshold_ms | Latency threshold (ms) | `number` | `5000` |
| alarm_actions | SNS ARNs for alerts | `list(string)` | `[]` |

See [variables.tf](./variables.tf) for complete list.

## Outputs

| Name | Description |
|------|-------------|
| log_group_name | CloudWatch log group name |
| log_group_arn | CloudWatch log group ARN |
| dashboard_name | Dashboard name (if created) |
| error_alarm_arn | Error alarm ARN (if enabled) |
| latency_alarm_arn | Latency alarm ARN (if enabled) |

See [outputs.tf](./outputs.tf) for complete list.

## Log Retention Periods

Valid retention values (in days):
- **1, 3, 5, 7** - Short-term (development)
- **14, 30** - Medium-term (staging)
- **60, 90, 120, 150, 180** - Long-term (production)
- **365** - 1 year
- **400, 545, 731** - Multi-year
- **1827, 3653** - 5-10 years (compliance)

**Recommendation**:
- Dev: 7 days
- Staging: 30 days
- Production: 90+ days

## Metric Filters

### Invocation Metric

**Purpose**: Track agent usage

**Filter Pattern**: `[timestamp, request_id, event_type=INVOCATION*, ...]`

**Metric**: `AgentInvocations` (Count)

**Use Case**: Monitor usage trends, capacity planning

### Error Metric

**Purpose**: Track error occurrences

**Filter Pattern**: `[timestamp, request_id, level=ERROR*, ...]`

**Metric**: `AgentErrors` (Count)

**Use Case**: Error rate monitoring, alerting

### Latency Metric

**Purpose**: Track response time

**Filter Pattern**: `[timestamp, request_id, ..., latency_ms=*latency*]`

**Metric**: `AgentLatency` (Milliseconds)

**Use Case**: Performance monitoring, SLA tracking

## CloudWatch Alarms

### Error Rate Alarm

**Triggers When**: Error count exceeds threshold in evaluation period

**Default**: 5 errors in 5 minutes

**Actions**: Sends SNS notification

**Use Case**: Immediate error detection

### High Latency Alarm

**Triggers When**: Average latency exceeds threshold

**Default**: 5000ms average over 2 periods (10 minutes)

**Actions**: Sends SNS notification

**Use Case**: Performance degradation detection

### No Invocations Alarm

**Triggers When**: No agent invocations in time window

**Default**: 0 invocations in 3 hours

**Actions**: Sends SNS notification

**Use Case**: Dead agent detection, availability monitoring

## CloudWatch Dashboard

Auto-generated dashboard includes:

1. **Invocations Widget**: Total invocations over time
2. **Errors Widget**: Error count tracking
3. **Latency Widget**: P50, P99, Average latency
4. **Log Insights Widget**: Recent log entries

Access: AWS Console → CloudWatch → Dashboards → `{project}-{env}-agent`

## CloudWatch Insights Queries

### Recent Errors

```
fields @timestamp, @message
| filter @message like /ERROR/
| sort @timestamp desc
| limit 20
```

### Invocation Count by Hour

```
fields @timestamp
| stats count() by bin(1h)
| sort bin(1h) desc
```

### Average Latency Over Time

```
fields @timestamp, latency_ms
| stats avg(latency_ms), max(latency_ms), min(latency_ms) by bin(5m)
```

### Error Rate Percentage

```
stats count(@message) as total,
      count(@message) filter @message like /ERROR/ as errors
| eval error_rate = errors / total * 100
```

### Top Error Types

```
fields @message
| filter @message like /ERROR/
| parse @message /ERROR: (?<error_type>[^:]+)/
| stats count() by error_type
| sort count() desc
```

## Cost Estimation

### Per Log Group (Monthly)

**Development** (1 GB/month, 7 days retention):
- Ingestion: ~$0.50
- Storage: ~$0.03
- Insights queries: ~$0.50
- **Total: ~$1.03/month**

**Production** (50 GB/month, 90 days retention):
- Ingestion: ~$25.00
- Storage: ~$1.50
- Insights queries: ~$5.00
- Alarms (3): ~$0.30
- Dashboard: Free
- **Total: ~$31.80/month**

### Cost Optimization

1. **Reduce retention**: 30 days vs 90 days saves 67% on storage
2. **Filter logs**: Only log errors in production
3. **Sampling**: Log 10% of successful requests
4. **Archive**: Export old logs to S3 Glacier

## Examples

### Complete Monitoring Setup

```hcl
# SNS topic for alerts
resource "aws_sns_topic" "alerts" {
  name = "${var.project_name}-${var.environment}-alerts"
}

# CloudWatch logs
module "cloudwatch_logs" {
  source = "../../modules/cloudwatch-logs"

  project_name      = var.project_name
  environment       = var.environment
  retention_in_days = var.environment == "prod" ? 90 : 7

  # All metrics enabled
  enable_invocation_metric = true
  enable_error_metric      = true
  enable_latency_metric    = true

  # All alarms enabled
  enable_error_alarm         = true
  enable_latency_alarm       = true
  enable_no_invocation_alarm = var.environment == "prod"

  # Notifications
  alarm_actions = [aws_sns_topic.alerts.arn]
  ok_actions    = [aws_sns_topic.alerts.arn]

  # Dashboard
  create_dashboard = true

  tags = var.common_tags
}

# Output for agent configuration
output "log_group_name" {
  value = module.cloudwatch_logs.log_group_name
}
```

## Troubleshooting

### Issue: No metrics appearing

**Cause**: Log filter patterns don't match log format

**Solution**:
1. Check actual log format: CloudWatch → Logs → View logs
2. Adjust filter patterns in variables
3. Test pattern: CloudWatch → Logs → Create metric filter → Test pattern

### Issue: Too many false alarms

**Cause**: Alarm thresholds too sensitive

**Solution**:
1. Increase `error_alarm_threshold` (5 → 10)
2. Increase `latency_alarm_threshold_ms` (5000 → 10000)
3. Increase `evaluation_periods` (1 → 2)

### Issue: Missing alarm notifications

**Cause**: SNS topic not configured or subscription not confirmed

**Solution**:
1. Verify SNS topic exists: `aws sns list-topics`
2. Check subscription: `aws sns list-subscriptions`
3. Confirm email subscription (check spam folder)

### Issue: High CloudWatch costs

**Cause**: Excessive log ingestion or long retention

**Solution**:
1. Reduce retention: 90 → 30 days
2. Filter logs: Only ERROR/WARN in production
3. Sample successful requests: Log 1 in 10

## Additional Resources

- [CloudWatch Logs Documentation](https://docs.aws.amazon.com/AmazonCloudWatch/latest/logs/)
- [CloudWatch Insights Query Syntax](https://docs.aws.amazon.com/AmazonCloudWatch/latest/logs/CWL_QuerySyntax.html)
- [CloudWatch Alarms](https://docs.aws.amazon.com/AmazonCloudWatch/latest/monitoring/AlarmThatSendsEmail.html)

## License

MIT - See main repository LICENSE file

---

**Module Version**: 1.0.0
**Last Updated**: 2026-02-05
