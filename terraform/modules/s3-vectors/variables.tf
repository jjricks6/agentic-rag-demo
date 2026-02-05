# Required Variables

variable "project_name" {
  description = "Name of the project (used in naming)"
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

variable "agent_role_names" {
  description = "List of IAM role names that should have access to vector storage"
  type        = list(string)
  default     = []
}

# Vector Configuration

variable "vector_dimensions" {
  description = "Number of dimensions for vector embeddings (must match embedding model)"
  type        = number
  default     = 1024 # Amazon Titan Embeddings v2 default

  validation {
    condition     = var.vector_dimensions > 0 && var.vector_dimensions <= 4096
    error_message = "Vector dimensions must be between 1 and 4096."
  }
}

variable "distance_metric" {
  description = "Distance metric for vector similarity (cosine, euclidean, inner_product)"
  type        = string
  default     = "cosine"

  validation {
    condition     = contains(["cosine", "euclidean", "inner_product"], var.distance_metric)
    error_message = "Distance metric must be cosine, euclidean, or inner_product."
  }
}

variable "index_type" {
  description = "Vector index type (hnsw for approximate nearest neighbor, flat for exact search)"
  type        = string
  default     = "hnsw"

  validation {
    condition     = contains(["hnsw", "flat"], var.index_type)
    error_message = "Index type must be hnsw or flat."
  }
}

# HNSW Index Parameters

variable "hnsw_m" {
  description = "HNSW index M parameter (number of connections per layer, 4-64)"
  type        = number
  default     = 16

  validation {
    condition     = var.hnsw_m >= 4 && var.hnsw_m <= 64
    error_message = "HNSW M must be between 4 and 64."
  }
}

variable "hnsw_ef_construction" {
  description = "HNSW index EF construction parameter (higher = better quality, slower indexing)"
  type        = number
  default     = 200

  validation {
    condition     = var.hnsw_ef_construction >= 100 && var.hnsw_ef_construction <= 512
    error_message = "HNSW EF construction must be between 100 and 512."
  }
}

variable "hnsw_ef_search" {
  description = "HNSW index EF search parameter (higher = better recall, slower search)"
  type        = number
  default     = 100

  validation {
    condition     = var.hnsw_ef_search >= 10 && var.hnsw_ef_search <= 512
    error_message = "HNSW EF search must be between 10 and 512."
  }
}

# Optional Variables - Monitoring

variable "enable_count_alarm" {
  description = "Enable CloudWatch alarm for vector count"
  type        = bool
  default     = false
}

variable "vector_count_alarm_threshold" {
  description = "Vector count threshold for alarm"
  type        = number
  default     = 1000000 # 1 million vectors

  validation {
    condition     = var.vector_count_alarm_threshold > 0
    error_message = "Threshold must be greater than 0."
  }
}

variable "enable_latency_alarm" {
  description = "Enable CloudWatch alarm for search latency"
  type        = bool
  default     = false
}

variable "latency_alarm_threshold_ms" {
  description = "Search latency threshold in milliseconds for alarm"
  type        = number
  default     = 1000 # 1 second

  validation {
    condition     = var.latency_alarm_threshold_ms > 0
    error_message = "Latency threshold must be greater than 0."
  }
}

variable "alarm_sns_topic_arns" {
  description = "List of SNS topic ARNs for alarm notifications"
  type        = list(string)
  default     = []
}

# Optional Variables - Backup

variable "enable_backup" {
  description = "Enable AWS Backup for vector bucket"
  type        = bool
  default     = false
}

variable "backup_role_arn" {
  description = "IAM role ARN for AWS Backup (required if enable_backup is true)"
  type        = string
  default     = null
}

variable "backup_plan_id" {
  description = "AWS Backup plan ID (required if enable_backup is true)"
  type        = string
  default     = null
}

# Optional Variables - General

variable "tags" {
  description = "Additional tags to apply to all resources"
  type        = map(string)
  default     = {}
}
