# Required Variables

variable "project_name" {
  description = "Name of the project (used in log group naming)"
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9-]+$", var.project_name))
    error_message = "Project name must contain only lowercase letters, numbers, and hyphens."
  }
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be dev, staging, or prod."
  }
}

# Log Group Configuration

variable "log_group_prefix" {
  description = "Prefix for the log group name (e.g., 'bedrock', 'lambda', 'ecs')"
  type        = string
  default     = "bedrock"

  validation {
    condition     = can(regex("^[a-z0-9-]+$", var.log_group_prefix))
    error_message = "Log group prefix must contain only lowercase letters, numbers, and hyphens."
  }
}

variable "retention_in_days" {
  description = "Number of days to retain logs"
  type        = number
  default     = 7

  validation {
    condition     = contains([1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365, 400, 545, 731, 1827, 3653], var.retention_in_days)
    error_message = "Retention must be a valid CloudWatch Logs retention period."
  }
}

variable "kms_key_id" {
  description = "KMS key ID for log encryption (if null, uses default encryption)"
  type        = string
  default     = null
}

# Metric Filters

variable "enable_invocation_metric" {
  description = "Enable metric filter for tracking invocations"
  type        = bool
  default     = true
}

variable "invocation_filter_pattern" {
  description = "Filter pattern for invocation metric"
  type        = string
  default     = "[timestamp, request_id, event_type=INVOCATION*, ...]"
}

variable "enable_error_metric" {
  description = "Enable metric filter for tracking errors"
  type        = bool
  default     = true
}

variable "error_filter_pattern" {
  description = "Filter pattern for error metric"
  type        = string
  default     = "[timestamp, request_id, level=ERROR*, ...]"
}

variable "enable_latency_metric" {
  description = "Enable metric filter for tracking latency"
  type        = bool
  default     = true
}

variable "latency_filter_pattern" {
  description = "Filter pattern for latency metric (must extract latency value)"
  type        = string
  default     = "[timestamp, request_id, ..., latency_ms=*latency*]"
}

variable "custom_metrics_namespace" {
  description = "CloudWatch namespace for custom metrics"
  type        = string
  default     = "AgenticRAG"

  validation {
    condition     = can(regex("^[a-zA-Z0-9-_/]+$", var.custom_metrics_namespace))
    error_message = "Namespace must contain only alphanumeric characters, hyphens, underscores, and forward slashes."
  }
}

# Subscription Filters

variable "enable_error_alerts" {
  description = "Enable subscription filter for error alerts"
  type        = bool
  default     = false
}

variable "error_destination_arn" {
  description = "ARN of destination for error alerts (Lambda, Kinesis, etc.)"
  type        = string
  default     = null
}

# Dashboard

variable "create_dashboard" {
  description = "Create CloudWatch dashboard for agent monitoring"
  type        = bool
  default     = true
}

# CloudWatch Alarms

variable "enable_error_alarm" {
  description = "Enable CloudWatch alarm for high error rate"
  type        = bool
  default     = true
}

variable "error_alarm_threshold" {
  description = "Number of errors to trigger alarm"
  type        = number
  default     = 5

  validation {
    condition     = var.error_alarm_threshold >= 1
    error_message = "Error alarm threshold must be at least 1."
  }
}

variable "error_alarm_evaluation_periods" {
  description = "Number of evaluation periods for error alarm"
  type        = number
  default     = 1

  validation {
    condition     = var.error_alarm_evaluation_periods >= 1
    error_message = "Evaluation periods must be at least 1."
  }
}

variable "error_alarm_period" {
  description = "Period in seconds for error alarm evaluation"
  type        = number
  default     = 300 # 5 minutes

  validation {
    condition     = var.error_alarm_period >= 60
    error_message = "Alarm period must be at least 60 seconds."
  }
}

variable "enable_latency_alarm" {
  description = "Enable CloudWatch alarm for high latency"
  type        = bool
  default     = true
}

variable "latency_alarm_threshold_ms" {
  description = "Latency threshold in milliseconds to trigger alarm"
  type        = number
  default     = 5000 # 5 seconds

  validation {
    condition     = var.latency_alarm_threshold_ms > 0
    error_message = "Latency threshold must be greater than 0."
  }
}

variable "latency_alarm_evaluation_periods" {
  description = "Number of evaluation periods for latency alarm"
  type        = number
  default     = 2

  validation {
    condition     = var.latency_alarm_evaluation_periods >= 1
    error_message = "Evaluation periods must be at least 1."
  }
}

variable "latency_alarm_period" {
  description = "Period in seconds for latency alarm evaluation"
  type        = number
  default     = 300 # 5 minutes

  validation {
    condition     = var.latency_alarm_period >= 60
    error_message = "Alarm period must be at least 60 seconds."
  }
}

variable "enable_no_invocation_alarm" {
  description = "Enable CloudWatch alarm for no invocations (dead agent detection)"
  type        = bool
  default     = false
}

variable "no_invocation_alarm_evaluation_periods" {
  description = "Number of evaluation periods for no invocation alarm"
  type        = number
  default     = 3

  validation {
    condition     = var.no_invocation_alarm_evaluation_periods >= 1
    error_message = "Evaluation periods must be at least 1."
  }
}

variable "no_invocation_alarm_period" {
  description = "Period in seconds for no invocation alarm evaluation"
  type        = number
  default     = 3600 # 1 hour

  validation {
    condition     = var.no_invocation_alarm_period >= 300
    error_message = "Alarm period must be at least 300 seconds (5 minutes)."
  }
}

variable "alarm_actions" {
  description = "List of ARNs to notify when alarm triggers (SNS topics, etc.)"
  type        = list(string)
  default     = []
}

variable "ok_actions" {
  description = "List of ARNs to notify when alarm returns to OK state"
  type        = list(string)
  default     = []
}

# Tags

variable "tags" {
  description = "Additional tags to apply to all resources"
  type        = map(string)
  default     = {}
}
