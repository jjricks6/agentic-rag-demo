# Production Environment Configuration
# This configuration deploys the complete Recall infrastructure for production

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 6.24.0"
    }
  }

  # Backend configuration
  backend "s3" {
    key            = "prod/terraform.tfstate"
    encrypt        = true
    # bucket, region, and dynamodb_table are provided via backend-config or command line
  }
}

# AWS Provider Configuration
provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = var.project_name
      Environment = var.environment
      ManagedBy   = "terraform"
      Repository  = "agentic-rag-demo"
      Criticality = "high"
    }
  }
}

# Get current AWS account and region
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

# Local variables
locals {
  common_tags = {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "terraform"
  }

  account_id = data.aws_caller_identity.current.account_id
  region     = data.aws_region.current.id
}

# ============================================================================
# CLOUDWATCH LOGS MODULE
# ============================================================================

module "cloudwatch_logs" {
  source = "../../modules/cloudwatch-logs"

  project_name      = var.project_name
  environment       = var.environment
  retention_in_days = var.log_retention_days

  # Metrics
  enable_invocation_metric = true
  enable_error_metric      = true
  enable_latency_metric    = true
  custom_metrics_namespace = "AgenticRAG/${var.environment}"

  # Alarms (strict thresholds for prod)
  enable_error_alarm             = true
  error_alarm_threshold          = 5  # Lower threshold for prod
  error_alarm_evaluation_periods = 2
  error_alarm_period             = 300

  enable_latency_alarm             = true
  latency_alarm_threshold_ms       = 5000 # 5 seconds
  latency_alarm_evaluation_periods = 2
  latency_alarm_period             = 300

  enable_no_invocation_alarm             = true # Monitor for dead agent
  no_invocation_alarm_evaluation_periods = 3
  no_invocation_alarm_period             = 3600 # 1 hour

  # Notifications (configure SNS topics)
  alarm_actions = var.alarm_sns_topic_arns
  ok_actions    = var.alarm_sns_topic_arns

  # Dashboard
  create_dashboard = true

  tags = local.common_tags
}

# ============================================================================
# IAM ROLES MODULE
# ============================================================================

module "iam_roles" {
  source = "../../modules/iam-roles"

  project_name = var.project_name
  environment  = var.environment

  documents_bucket_arns = [module.s3_storage.bucket_arn]
  vectors_bucket_arns   = [module.s3_vectors.vector_bucket_arn]
  vector_index_arns     = [module.s3_vectors.vector_index_arn]

  # Bedrock model access
  bedrock_model_arns = [
    "arn:aws:bedrock:${local.region}::foundation-model/${var.embedding_model_id}",
    "arn:aws:bedrock:${local.region}::foundation-model/${var.llm_model_id}"
  ]

  log_group_arns = [module.cloudwatch_logs.log_group_arn]

  enable_agent_operations = true

  tags = local.common_tags
}

# ============================================================================
# S3 STORAGE MODULE (Documents)
# ============================================================================

module "s3_storage" {
  source = "../../modules/s3-storage"

  project_name     = var.project_name
  environment      = var.environment
  bucket_suffix    = "documents"
  agent_role_arns  = [module.iam_roles.role_arn]

  # Production settings
  enable_versioning                = true # Enable for data protection
  noncurrent_version_retention_days = 90
  enable_lifecycle_rules           = true
  force_destroy                    = false # Prevent accidental deletion

  # Glacier transition for cost savings
  enable_glacier_transition  = var.enable_glacier_transition
  glacier_transition_days    = var.glacier_transition_days
  glacier_transition_prefix  = "archive/"

  # CORS for production UI
  enable_cors          = var.enable_cors
  cors_allowed_origins = var.cors_allowed_origins
  cors_allowed_methods = ["GET", "PUT", "POST"]

  # Monitoring
  enable_size_alarm         = true
  size_alarm_threshold_bytes = var.storage_alarm_threshold_bytes
  alarm_sns_topic_arns      = var.alarm_sns_topic_arns

  tags = local.common_tags
}

# ============================================================================
# S3 VECTORS MODULE
# ============================================================================

module "s3_vectors" {
  source = "../../modules/s3-vectors"

  project_name      = var.project_name
  environment       = var.environment
  agent_role_names  = [module.iam_roles.role_name]

  # Vector configuration
  vector_dimensions = var.vector_dimensions
  distance_metric   = var.distance_metric
  index_type        = "hnsw"

  # HNSW parameters (production settings - better accuracy)
  hnsw_m              = 32   # More connections = better recall
  hnsw_ef_construction = 400 # Higher quality index
  hnsw_ef_search      = 200  # Better search accuracy

  # Monitoring
  enable_count_alarm            = true
  enable_latency_alarm          = true
  vector_count_alarm_threshold  = var.vector_count_alarm_threshold
  latency_alarm_threshold_ms    = 1000 # 1 second for prod
  alarm_sns_topic_arns          = var.alarm_sns_topic_arns

  # Backup (optional)
  enable_backup = var.enable_backup
  backup_role_arn = var.backup_role_arn
  backup_plan_id  = var.backup_plan_id

  tags = local.common_tags
}

# ============================================================================
# LAMBDA FUNCTIONS (Action Group Handlers)
# ============================================================================

# IAM role for Lambda functions
resource "aws_iam_role" "lambda_execution" {
  name = "${var.project_name}-lambda-${var.environment}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = local.common_tags
}

# Lambda policy
resource "aws_iam_role_policy" "lambda_policy" {
  name = "${var.project_name}-lambda-policy-${var.environment}"
  role = aws_iam_role.lambda_execution.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:*:*:*"
      },
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:ListBucket"
        ]
        Resource = [
          module.s3_storage.bucket_arn,
          "${module.s3_storage.bucket_arn}/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "s3vectors:*"
        ]
        Resource = [
          module.s3_vectors.vector_bucket_arn,
          "${module.s3_vectors.vector_bucket_arn}/*",
          module.s3_vectors.vector_index_arn
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "bedrock:InvokeModel"
        ]
        Resource = [
          "arn:aws:bedrock:${local.region}::foundation-model/${var.embedding_model_id}"
        ]
      }
    ]
  })
}

# Lambda for Document Management
resource "aws_lambda_function" "document_handler" {
  filename      = "${path.module}/lambda-placeholder.zip"
  function_name = "${var.project_name}-document-handler-${var.environment}"
  role          = aws_iam_role.lambda_execution.arn
  handler       = "index.handler"
  runtime       = "python3.11"
  timeout       = 90  # Longer timeout for prod
  memory_size   = 1024 # More memory for prod

  # Reserved concurrency for predictable performance
  reserved_concurrent_executions = var.lambda_reserved_concurrency

  environment {
    variables = {
      DOCUMENTS_BUCKET = module.s3_storage.bucket_id
      VECTORS_BUCKET   = module.s3_vectors.vector_bucket_name
      VECTOR_INDEX     = module.s3_vectors.vector_index_name
      EMBEDDING_MODEL  = var.embedding_model_id
      ENVIRONMENT      = var.environment
    }
  }

  tags = local.common_tags

  lifecycle {
    ignore_changes = [filename, source_code_hash]
  }
}

# Lambda for Vector Search
resource "aws_lambda_function" "search_handler" {
  filename      = "${path.module}/lambda-placeholder.zip"
  function_name = "${var.project_name}-search-handler-${var.environment}"
  role          = aws_iam_role.lambda_execution.arn
  handler       = "index.handler"
  runtime       = "python3.11"
  timeout       = 60
  memory_size   = 512

  reserved_concurrent_executions = var.lambda_reserved_concurrency

  environment {
    variables = {
      VECTORS_BUCKET  = module.s3_vectors.vector_bucket_name
      VECTOR_INDEX    = module.s3_vectors.vector_index_name
      EMBEDDING_MODEL = var.embedding_model_id
      ENVIRONMENT     = var.environment
    }
  }

  tags = local.common_tags

  lifecycle {
    ignore_changes = [filename, source_code_hash]
  }
}

# Lambda permissions
resource "aws_lambda_permission" "allow_bedrock_document" {
  statement_id  = "AllowBedrockAgent"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.document_handler.function_name
  principal     = "bedrock.amazonaws.com"
  source_arn    = "arn:aws:bedrock:${local.region}:${local.account_id}:agent/*"
}

resource "aws_lambda_permission" "allow_bedrock_search" {
  statement_id  = "AllowBedrockAgent"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.search_handler.function_name
  principal     = "bedrock.amazonaws.com"
  source_arn    = "arn:aws:bedrock:${local.region}:${local.account_id}:agent/*"
}

# ============================================================================
# BEDROCK AGENT MODULE
# ============================================================================

module "bedrock_agent" {
  source = "../../modules/bedrock-agent"

  project_name    = var.project_name
  environment     = var.environment
  agent_role_arn  = module.iam_roles.role_arn

  document_lambda_arn = aws_lambda_function.document_handler.arn
  search_lambda_arn   = aws_lambda_function.search_handler.arn

  foundation_model_id = var.llm_model_id

  # Production model parameters
  temperature = 0.5  # Lower for more deterministic responses
  max_tokens  = 4096 # Higher for detailed responses
  top_p       = 0.95

  # Session management
  idle_session_ttl_seconds = 1800 # 30 minutes

  agent_instruction = var.agent_instruction

  tags = local.common_tags

  depends_on = [
    aws_lambda_function.document_handler,
    aws_lambda_function.search_handler,
    aws_lambda_permission.allow_bedrock_document,
    aws_lambda_permission.allow_bedrock_search
  ]
}
