# Development Environment Configuration
# This configuration deploys the complete Recall infrastructure

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 6.24.0"
    }
  }

  # Backend configuration - update with your backend bucket details
  # Initialize with: terraform init -backend-config="bucket=YOUR_BUCKET_NAME"
  backend "s3" {
    key            = "dev/terraform.tfstate"
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

  # Alarms (relaxed thresholds for dev)
  enable_error_alarm             = var.enable_cloudwatch_alarms
  error_alarm_threshold          = 10
  error_alarm_evaluation_periods = 1
  error_alarm_period             = 300

  enable_latency_alarm             = var.enable_cloudwatch_alarms
  latency_alarm_threshold_ms       = 10000 # 10 seconds for dev
  latency_alarm_evaluation_periods = 2
  latency_alarm_period             = 300

  enable_no_invocation_alarm = false # Disabled in dev

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

  # These will be populated after other modules are created
  documents_bucket_arns = [module.s3_storage.bucket_arn]
  vectors_bucket_arns   = [module.s3_vectors.vector_bucket_arn]
  vector_index_arns     = [module.s3_vectors.vector_index_arn]

  # Bedrock model access
  bedrock_model_arns = [
    "arn:aws:bedrock:${local.region}::foundation-model/${var.embedding_model_id}",
    "arn:aws:bedrock:${local.region}::foundation-model/${var.llm_model_id}"
  ]

  # CloudWatch Logs access
  log_group_arns = [module.cloudwatch_logs.log_group_arn]

  # Enable agent operations
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

  # Dev settings
  enable_versioning      = false # Disabled for cost savings in dev
  enable_lifecycle_rules = true
  force_destroy          = true  # Allow easy cleanup in dev

  # CORS for local Streamlit
  enable_cors          = true
  cors_allowed_origins = ["http://localhost:8501", "http://localhost:3000"]
  cors_allowed_methods = ["GET", "PUT", "POST", "DELETE"]

  # Monitoring
  enable_size_alarm         = false # Disabled in dev
  size_alarm_threshold_bytes = 10737418240 # 10 GB

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

  # HNSW parameters (dev settings - faster, less accurate)
  hnsw_m              = 16
  hnsw_ef_construction = 200
  hnsw_ef_search      = 100

  # Monitoring
  enable_count_alarm            = false # Disabled in dev
  enable_latency_alarm          = false # Disabled in dev
  vector_count_alarm_threshold  = 100000

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

# Lambda policy for S3 and Bedrock access
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

# Placeholder Lambda for Document Management
# TODO: Replace with actual implementation from agent/lambda/ directory
resource "aws_lambda_function" "document_handler" {
  filename      = "${path.module}/lambda-placeholder.zip"
  function_name = "${var.project_name}-document-handler-${var.environment}"
  role          = aws_iam_role.lambda_execution.arn
  handler       = "index.handler"
  runtime       = "python3.11"
  timeout       = 60
  memory_size   = 512

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

  # This will fail until we create the placeholder zip
  # For now, lifecycle ignore to allow planning
  lifecycle {
    ignore_changes = [filename, source_code_hash]
  }
}

# Placeholder Lambda for Vector Search
# TODO: Replace with actual implementation from agent/lambda/ directory
resource "aws_lambda_function" "search_handler" {
  filename      = "${path.module}/lambda-placeholder.zip"
  function_name = "${var.project_name}-search-handler-${var.environment}"
  role          = aws_iam_role.lambda_execution.arn
  handler       = "index.handler"
  runtime       = "python3.11"
  timeout       = 30
  memory_size   = 256

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

# Lambda permissions for Bedrock Agent
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

  # Lambda functions for action groups
  document_lambda_arn = aws_lambda_function.document_handler.arn
  search_lambda_arn   = aws_lambda_function.search_handler.arn

  # Foundation model
  foundation_model_id = var.llm_model_id

  # Model parameters (relaxed for dev)
  temperature = 0.7
  max_tokens  = 2048
  top_p       = 0.9

  # Session management
  idle_session_ttl_seconds = 600 # 10 minutes

  # Custom agent instructions
  agent_instruction = var.agent_instruction

  tags = local.common_tags

  depends_on = [
    aws_lambda_function.document_handler,
    aws_lambda_function.search_handler,
    aws_lambda_permission.allow_bedrock_document,
    aws_lambda_permission.allow_bedrock_search
  ]
}

# ============================================================================
# SSM PARAMETER STORE (Agent Configuration)
# ============================================================================
# These parameters are read by the Strands Agent at startup via
# SSM_PARAMETER_PREFIX=/${var.project_name}/${var.environment}
# This eliminates the need to manually pass environment variables.

locals {
  ssm_prefix = "/${var.project_name}/${var.environment}"

  ssm_parameters = {
    documents_bucket = module.s3_storage.bucket_id
    vectors_bucket   = module.s3_vectors.vector_bucket_name
    vector_index     = module.s3_vectors.vector_index_name
    embedding_model  = var.embedding_model_id
    llm_model        = var.llm_model_id
    vector_dimensions = tostring(var.vector_dimensions)
    aws_region       = local.region
    environment      = var.environment
  }
}

resource "aws_ssm_parameter" "agent_config" {
  for_each = local.ssm_parameters

  name  = "${local.ssm_prefix}/${each.key}"
  type  = "String"
  value = each.value

  tags = merge(local.common_tags, {
    Purpose = "Agent configuration parameter"
  })
}

# IAM policy for reading SSM parameters (attached to agent role)
resource "aws_iam_role_policy" "ssm_config_read" {
  name = "${var.project_name}-ssm-config-${var.environment}"
  role = module.iam_roles.role_name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ssm:GetParametersByPath",
          "ssm:GetParameters",
          "ssm:GetParameter"
        ]
        Resource = "arn:aws:ssm:${local.region}:${local.account_id}:parameter${local.ssm_prefix}/*"
      }
    ]
  })
}
