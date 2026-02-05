variable "aws_region" {
  description = "AWS region for the Terraform state backend"
  type        = string
  default     = "us-east-1"

  validation {
    condition     = can(regex("^[a-z]{2}-[a-z]+-[0-9]{1}$", var.aws_region))
    error_message = "AWS region must be in format: us-east-1, eu-west-1, etc."
  }
}

variable "project_name" {
  description = "Project name used for naming resources (must be globally unique)"
  type        = string
  default     = "agentic-rag-demo"

  validation {
    condition     = can(regex("^[a-z0-9-]+$", var.project_name))
    error_message = "Project name must contain only lowercase letters, numbers, and hyphens."
  }
}

variable "state_version_retention_days" {
  description = "Number of days to retain noncurrent versions of state files"
  type        = number
  default     = 90

  validation {
    condition     = var.state_version_retention_days >= 30
    error_message = "State version retention must be at least 30 days for safety."
  }
}

variable "log_retention_days" {
  description = "Number of days to retain S3 access logs"
  type        = number
  default     = 30

  validation {
    condition     = var.log_retention_days >= 7
    error_message = "Log retention must be at least 7 days."
  }
}

variable "enable_kms_encryption" {
  description = "Enable KMS encryption for state bucket (additional cost)"
  type        = bool
  default     = false
}

variable "tags" {
  description = "Additional tags to apply to all resources"
  type        = map(string)
  default     = {}
}
