# Development Environment Variables

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
  description = "Name of the project (used for resource naming)"
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
  default     = "dev"

  validation {
    condition     = var.environment == "dev"
    error_message = "This configuration is for dev environment only."
  }
}

# ============================================================================
# Bedrock Model Configuration
# ============================================================================

variable "llm_model_id" {
  description = "Bedrock LLM model ID for the agent"
  type        = string
  default     = "anthropic.claude-3-5-sonnet-20250110-v1:0"

  validation {
    condition     = can(regex("^(anthropic|amazon|cohere|meta|ai21)\\.", var.llm_model_id))
    error_message = "LLM model ID must be a valid Bedrock model identifier."
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
  description = "Dimensions of vector embeddings (must match embedding model)"
  type        = number
  default     = 1024 # Amazon Titan Embeddings v2

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
  description = "Instructions for the agent on how to behave"
  type        = string
  default     = <<-EOT
    You are a helpful AI assistant specializing in document management and retrieval for the Agentic RAG Demo.

    Your capabilities include:
    1. **Document Upload**: Accept documents from users and store them securely in S3
    2. **Document Search**: Search through uploaded documents to find relevant information
    3. **Question Answering**: Answer questions based on the content of stored documents
    4. **Document Management**: List and delete documents as needed

    Guidelines:
    - Always acknowledge document uploads and confirm successful indexing
    - When answering questions, cite the specific documents you're referencing
    - If you can't find relevant information, say so clearly
    - Be concise but thorough in your responses
    - Maintain a professional and helpful tone

    This is a development environment, so feel free to be more verbose about what you're doing.
  EOT
}

# ============================================================================
# Monitoring Configuration
# ============================================================================

variable "log_retention_days" {
  description = "Number of days to retain CloudWatch logs"
  type        = number
  default     = 7

  validation {
    condition     = contains([1, 3, 5, 7, 14, 30], var.log_retention_days)
    error_message = "For dev, log retention should be 1, 3, 5, 7, 14, or 30 days."
  }
}

variable "enable_cloudwatch_alarms" {
  description = "Enable CloudWatch alarms (may want to disable in dev to reduce noise)"
  type        = bool
  default     = false
}

# ============================================================================
# Tags
# ============================================================================

variable "tags" {
  description = "Additional tags to apply to all resources"
  type        = map(string)
  default = {
    CostCenter = "Development"
    Owner      = "DevTeam"
  }
}
