# Required Variables

variable "project_name" {
  description = "Name of the project (used in bucket naming)"
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

variable "bucket_suffix" {
  description = "Suffix for the bucket name (e.g., 'documents', 'data')"
  type        = string
  default     = "documents"
}

variable "agent_role_arns" {
  description = "List of IAM role ARNs that should have access to this bucket"
  type        = list(string)
  default     = []
}

# Optional Variables - Encryption

variable "kms_key_id" {
  description = "KMS key ID for bucket encryption (if null, uses AES256)"
  type        = string
  default     = null
}

# Optional Variables - Versioning

variable "enable_versioning" {
  description = "Enable versioning for the S3 bucket"
  type        = bool
  default     = false
}

# Optional Variables - Lifecycle Rules

variable "enable_lifecycle_rules" {
  description = "Enable lifecycle rules for cost optimization"
  type        = bool
  default     = true
}

variable "noncurrent_version_retention_days" {
  description = "Number of days to retain noncurrent object versions"
  type        = number
  default     = 30

  validation {
    condition     = var.noncurrent_version_retention_days >= 1
    error_message = "Retention days must be at least 1."
  }
}

variable "enable_glacier_transition" {
  description = "Enable automatic transition to Glacier storage"
  type        = bool
  default     = false
}

variable "glacier_transition_days" {
  description = "Number of days before transitioning objects to Glacier"
  type        = number
  default     = 90

  validation {
    condition     = var.glacier_transition_days >= 30
    error_message = "Glacier transition must be at least 30 days."
  }
}

variable "glacier_transition_prefix" {
  description = "Object prefix for Glacier transition (e.g., 'archive/')"
  type        = string
  default     = "archive/"
}

variable "abort_incomplete_multipart_upload_days" {
  description = "Days after which incomplete multipart uploads are aborted"
  type        = number
  default     = 7

  validation {
    condition     = var.abort_incomplete_multipart_upload_days >= 1
    error_message = "Must be at least 1 day."
  }
}

# Optional Variables - CORS

variable "enable_cors" {
  description = "Enable CORS configuration for web uploads"
  type        = bool
  default     = false
}

variable "cors_allowed_headers" {
  description = "List of allowed headers for CORS"
  type        = list(string)
  default     = ["*"]
}

variable "cors_allowed_methods" {
  description = "List of allowed HTTP methods for CORS"
  type        = list(string)
  default     = ["GET", "PUT", "POST", "DELETE", "HEAD"]
}

variable "cors_allowed_origins" {
  description = "List of allowed origins for CORS"
  type        = list(string)
  default     = ["*"]
}

variable "cors_expose_headers" {
  description = "List of headers to expose in CORS responses"
  type        = list(string)
  default     = ["ETag"]
}

variable "cors_max_age_seconds" {
  description = "Max age for CORS preflight cache (in seconds)"
  type        = number
  default     = 3600
}

# Optional Variables - Notifications

variable "notification_lambda_arns" {
  description = "List of Lambda function ARNs to notify on object creation"
  type        = list(string)
  default     = []
}

variable "notification_filter_prefix" {
  description = "Object key prefix filter for notifications"
  type        = string
  default     = ""
}

variable "notification_filter_suffix" {
  description = "Object key suffix filter for notifications (e.g., '.pdf')"
  type        = string
  default     = ""
}

# Optional Variables - Monitoring

variable "enable_size_alarm" {
  description = "Enable CloudWatch alarm for bucket size"
  type        = bool
  default     = false
}

variable "size_alarm_threshold_bytes" {
  description = "Bucket size threshold in bytes for alarm"
  type        = number
  default     = 107374182400 # 100 GB

  validation {
    condition     = var.size_alarm_threshold_bytes > 0
    error_message = "Threshold must be greater than 0."
  }
}

variable "alarm_sns_topic_arns" {
  description = "List of SNS topic ARNs for alarm notifications"
  type        = list(string)
  default     = []
}

# Optional Variables - General

variable "force_destroy" {
  description = "Allow destroying bucket even if it contains objects (use with caution)"
  type        = bool
  default     = false
}

variable "tags" {
  description = "Additional tags to apply to all resources"
  type        = map(string)
  default     = {}
}
