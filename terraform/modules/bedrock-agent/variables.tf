# Required Variables

variable "project_name" {
  description = "Name of the project (used in agent naming)"
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

variable "agent_role_arn" {
  description = "ARN of the IAM role for the agent to assume"
  type        = string

  validation {
    condition     = can(regex("^arn:aws:iam::[0-9]{12}:role/", var.agent_role_arn))
    error_message = "Agent role ARN must be a valid IAM role ARN."
  }
}

variable "foundation_model_id" {
  description = "ID of the foundation model to use for the agent"
  type        = string
  default     = "anthropic.claude-3-5-sonnet-20250110-v1:0"

  validation {
    condition     = can(regex("^(anthropic|amazon|cohere|meta|ai21)\\.", var.foundation_model_id))
    error_message = "Foundation model ID must be a valid Bedrock model identifier."
  }
}

# Agent Configuration

variable "agent_instruction" {
  description = "Instructions for the agent on how to behave and respond"
  type        = string
  default     = <<-EOT
    You are a helpful AI assistant specializing in document management and retrieval.

    Your capabilities include:
    1. Accepting document uploads from users and storing them securely
    2. Searching through uploaded documents to find relevant information
    3. Answering questions based on the content of stored documents
    4. Managing the document collection (listing, deleting)

    When a user uploads a document:
    - Acknowledge the upload and confirm it was successful
    - Inform them that the document has been indexed and is now searchable

    When answering questions:
    - Search through the document collection to find relevant information
    - Always cite which documents you're referencing
    - If you can't find relevant information, say so clearly
    - Be concise but thorough in your responses

    Be helpful, accurate, and professional in all interactions.
  EOT
}

variable "idle_session_ttl_seconds" {
  description = "Idle session timeout in seconds"
  type        = number
  default     = 600 # 10 minutes

  validation {
    condition     = var.idle_session_ttl_seconds >= 60 && var.idle_session_ttl_seconds <= 3600
    error_message = "Idle session TTL must be between 60 and 3600 seconds."
  }
}

# Model Parameters

variable "enable_prompt_override" {
  description = "Enable custom prompt override configuration"
  type        = bool
  default     = false
}

variable "base_prompt_template" {
  description = "Base prompt template for the agent (if prompt override is enabled)"
  type        = string
  default     = null
}

variable "max_tokens" {
  description = "Maximum number of tokens to generate"
  type        = number
  default     = 2048

  validation {
    condition     = var.max_tokens >= 1 && var.max_tokens <= 4096
    error_message = "Max tokens must be between 1 and 4096."
  }
}

variable "temperature" {
  description = "Sampling temperature (0.0-1.0)"
  type        = number
  default     = 0.7

  validation {
    condition     = var.temperature >= 0 && var.temperature <= 1
    error_message = "Temperature must be between 0 and 1."
  }
}

variable "top_p" {
  description = "Top P sampling parameter (0.0-1.0)"
  type        = number
  default     = 0.9

  validation {
    condition     = var.top_p >= 0 && var.top_p <= 1
    error_message = "Top P must be between 0 and 1."
  }
}

variable "stop_sequences" {
  description = "List of sequences that will stop generation"
  type        = list(string)
  default     = []
}

variable "parser_mode" {
  description = "Parser mode for prompt (DEFAULT or OVERRIDDEN)"
  type        = string
  default     = "DEFAULT"

  validation {
    condition     = contains(["DEFAULT", "OVERRIDDEN"], var.parser_mode)
    error_message = "Parser mode must be DEFAULT or OVERRIDDEN."
  }
}

variable "prompt_creation_mode" {
  description = "How the prompt is created (DEFAULT or OVERRIDDEN)"
  type        = string
  default     = "DEFAULT"

  validation {
    condition     = contains(["DEFAULT", "OVERRIDDEN"], var.prompt_creation_mode)
    error_message = "Prompt creation mode must be DEFAULT or OVERRIDDEN."
  }
}

variable "prompt_state" {
  description = "State of the prompt (ENABLED or DISABLED)"
  type        = string
  default     = "ENABLED"

  validation {
    condition     = contains(["ENABLED", "DISABLED"], var.prompt_state)
    error_message = "Prompt state must be ENABLED or DISABLED."
  }
}

# Action Groups - Lambda ARNs

variable "document_lambda_arn" {
  description = "ARN of the Lambda function for document management actions"
  type        = string

  validation {
    condition     = can(regex("^arn:aws:lambda:", var.document_lambda_arn))
    error_message = "Document Lambda ARN must be a valid Lambda function ARN."
  }
}

variable "search_lambda_arn" {
  description = "ARN of the Lambda function for vector search actions"
  type        = string

  validation {
    condition     = can(regex("^arn:aws:lambda:", var.search_lambda_arn))
    error_message = "Search Lambda ARN must be a valid Lambda function ARN."
  }
}

# Versioning

variable "agent_version" {
  description = "Agent version to use (null for DRAFT)"
  type        = string
  default     = null
}

variable "skip_resource_in_use_check" {
  description = "Skip check for resources in use during updates"
  type        = bool
  default     = true
}

# Tags

variable "tags" {
  description = "Additional tags to apply to all resources"
  type        = map(string)
  default     = {}
}
