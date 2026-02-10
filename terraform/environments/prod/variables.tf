# Production Environment Variables

# ============================================================================
# Required Variables
# ============================================================================

variable "aws_region" {
  description = "AWS region for deployment"
  type        = string
  default     = "us-east-1"

  validation {
    condition     = can(regex("^[a-z]{2}-[a-z]+-[0-9]{1}$", var.aws_region))
    error_message = "AWS region must be in format: us-east-1, eu-west-1, etc."
  }
}

variable "project_name" {
  description = "Name of the project"
  type        = string
  default     = "agentic-rag-demo"

  validation {
    condition     = can(regex("^[a-z0-9-]+$", var.project_name))
    error_message = "Project name must contain only lowercase letters, numbers, and hyphens."
  }
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "prod"

  validation {
    condition     = var.environment == "prod"
    error_message = "This configuration is for prod environment only."
  }
}

# ============================================================================
# Bedrock Model Configuration
# ============================================================================

variable "llm_model_id" {
  description = "Bedrock LLM model ID or inference profile ID for the agent"
  type        = string
  default     = "us.anthropic.claude-3-5-sonnet-20241022-v2:0"

  validation {
    condition     = can(regex("^(us\\.|global\\.)?(anthropic|amazon|cohere|meta|ai21)\\.", var.llm_model_id))
    error_message = "LLM model ID must be a valid Bedrock model or inference profile identifier."
  }
}

variable "embedding_model_id" {
  description = "Bedrock embeddings model ID"
  type        = string
  default     = "amazon.titan-embed-text-v2:0"

  validation {
    condition     = can(regex("^(amazon|cohere)\\.", var.embedding_model_id))
    error_message = "Embedding model ID must be a valid Bedrock embeddings model."
  }
}

# ============================================================================
# Vector Configuration
# ============================================================================

variable "vector_dimensions" {
  description = "Dimensions of vector embeddings"
  type        = number
  default     = 1024

  validation {
    condition     = var.vector_dimensions > 0 && var.vector_dimensions <= 4096
    error_message = "Vector dimensions must be between 1 and 4096."
  }
}

variable "distance_metric" {
  description = "Distance metric for vector similarity"
  type        = string
  default     = "cosine"

  validation {
    condition     = contains(["cosine", "euclidean", "inner_product"], var.distance_metric)
    error_message = "Distance metric must be cosine, euclidean, or inner_product."
  }
}

# ============================================================================
# Agent Configuration
# ============================================================================

variable "agent_instruction" {
  description = "Instructions for the agent"
  type        = string
  default     = <<-EOT
    You are a professional AI assistant for the Recall production system.

    Your capabilities:
    1. **Document Upload**: Accept and securely store documents
    2. **Document Search**: Search through indexed documents
    3. **Question Answering**: Provide accurate answers with citations
    4. **Document Management**: List and manage documents

    Production guidelines:
    - Always cite sources accurately
    - If information is not found, state this clearly
    - Maintain professional tone
    - Be concise and accurate
    - Prioritize data security and privacy

    This is a production environment - ensure all responses are accurate and well-sourced.
  EOT
}

# ============================================================================
# Storage Configuration
# ============================================================================

variable "enable_glacier_transition" {
  description = "Enable automatic transition to Glacier for cost savings"
  type        = bool
  default     = true
}

variable "glacier_transition_days" {
  description = "Days before transitioning documents to Glacier"
  type        = number
  default     = 180

  validation {
    condition     = var.glacier_transition_days >= 30
    error_message = "Glacier transition must be at least 30 days."
  }
}

variable "enable_cors" {
  description = "Enable CORS for web application access"
  type        = bool
  default     = true
}

variable "cors_allowed_origins" {
  description = "Allowed origins for CORS"
  type        = list(string)
  default     = ["https://app.example.com"] # Update with your production domain
}

# ============================================================================
# Monitoring Configuration
# ============================================================================

variable "log_retention_days" {
  description = "Number of days to retain CloudWatch logs"
  type        = number
  default     = 90

  validation {
    condition     = contains([30, 60, 90, 120, 180, 365], var.log_retention_days)
    error_message = "For prod, log retention should be 30, 60, 90, 120, 180, or 365 days."
  }
}

variable "alarm_sns_topic_arns" {
  description = "SNS topic ARNs for alarm notifications"
  type        = list(string)
  default     = []
}

variable "storage_alarm_threshold_bytes" {
  description = "S3 storage size threshold for alarms (in bytes)"
  type        = number
  default     = 107374182400 # 100 GB

  validation {
    condition     = var.storage_alarm_threshold_bytes > 0
    error_message = "Storage threshold must be greater than 0."
  }
}

variable "vector_count_alarm_threshold" {
  description = "Vector count threshold for alarms"
  type        = number
  default     = 1000000 # 1 million vectors

  validation {
    condition     = var.vector_count_alarm_threshold > 0
    error_message = "Vector count threshold must be greater than 0."
  }
}

# ============================================================================
# Lambda Configuration
# ============================================================================

variable "lambda_reserved_concurrency" {
  description = "Reserved concurrent executions for Lambda functions"
  type        = number
  default     = 10

  validation {
    condition     = var.lambda_reserved_concurrency >= 1
    error_message = "Reserved concurrency must be at least 1."
  }
}

# ============================================================================
# Backup Configuration
# ============================================================================

variable "enable_backup" {
  description = "Enable AWS Backup for vector storage"
  type        = bool
  default     = false
}

variable "backup_role_arn" {
  description = "IAM role ARN for AWS Backup"
  type        = string
  default     = null
}

variable "backup_plan_id" {
  description = "AWS Backup plan ID"
  type        = string
  default     = null
}

# ============================================================================
# Tags
# ============================================================================

variable "tags" {
  description = "Additional tags to apply to all resources"
  type        = map(string)
  default = {
    CostCenter  = "Production"
    Criticality = "High"
  }
}
