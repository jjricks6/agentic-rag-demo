# Required Variables

variable "project_name" {
  description = "Name of the project (used in role naming)"
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

# Trust Relationship

variable "trusted_services" {
  description = "List of AWS service principals that can assume this role"
  type        = list(string)
  default = [
    "bedrock.amazonaws.com",
    "agentcore.amazonaws.com"
  ]

  validation {
    condition     = length(var.trusted_services) > 0
    error_message = "At least one trusted service must be specified."
  }
}

# S3 Access

variable "documents_bucket_arns" {
  description = "List of S3 bucket ARNs for document storage"
  type        = list(string)
  default     = []
}

variable "vectors_bucket_arns" {
  description = "List of S3 Vector Bucket ARNs for vector storage"
  type        = list(string)
  default     = []
}

variable "vector_index_arns" {
  description = "List of S3 Vector Index ARNs for vector search operations"
  type        = list(string)
  default     = []
}

# Bedrock Access

variable "bedrock_model_arns" {
  description = "List of Bedrock model ARNs the agent can invoke"
  type        = list(string)
  default     = []

  # If empty, defaults to all models in the account/region
  # Format: arn:aws:bedrock:region:account:foundation-model/model-id
}

variable "enable_agent_operations" {
  description = "Enable Bedrock agent-specific operations"
  type        = bool
  default     = true
}

# CloudWatch Logs

variable "log_group_arns" {
  description = "List of CloudWatch Log Group ARNs for agent logging"
  type        = list(string)
  default     = []

  # If empty, allows creation/writing to /aws/bedrock/* log groups
}

# Encryption

variable "kms_key_arns" {
  description = "List of KMS key ARNs for encryption/decryption"
  type        = list(string)
  default     = []
}

# Additional Policies

variable "additional_policy_arns" {
  description = "List of additional IAM policy ARNs to attach to the role"
  type        = list(string)
  default     = []
}

# Role Configuration

variable "max_session_duration" {
  description = "Maximum session duration in seconds (3600-43200)"
  type        = number
  default     = 3600

  validation {
    condition     = var.max_session_duration >= 3600 && var.max_session_duration <= 43200
    error_message = "Session duration must be between 1 and 12 hours (3600-43200 seconds)."
  }
}

# Tags

variable "tags" {
  description = "Additional tags to apply to all resources"
  type        = map(string)
  default     = {}
}
