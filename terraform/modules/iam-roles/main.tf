# IAM Roles Module for Agent Permissions
# This module creates IAM roles and policies for the Bedrock agent

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 6.24.0"
    }
  }
}

# Get current AWS account ID and region
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

# Generate role name
locals {
  role_name = "${var.project_name}-agent-role-${var.environment}"
}

# IAM role for the Bedrock agent
resource "aws_iam_role" "agent" {
  name               = local.role_name
  description        = "IAM role for ${var.project_name} agent in ${var.environment}"
  assume_role_policy = data.aws_iam_policy_document.agent_assume_role.json

  max_session_duration = var.max_session_duration

  tags = merge(
    var.tags,
    {
      Name        = local.role_name
      Environment = var.environment
      Purpose     = "Bedrock Agent Execution Role"
    }
  )
}

# Trust policy for Bedrock agent
data "aws_iam_policy_document" "agent_assume_role" {
  statement {
    sid     = "AllowBedrockAgentAssumeRole"
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = var.trusted_services
    }

    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [data.aws_caller_identity.current.account_id]
    }

    condition {
      test     = "ArnLike"
      variable = "aws:SourceArn"
      values   = ["arn:aws:bedrock:${data.aws_region.current.id}:${data.aws_caller_identity.current.account_id}:agent/*"]
    }
  }
}

# Policy for S3 documents bucket access
resource "aws_iam_policy" "s3_documents" {
  name        = "${local.role_name}-s3-documents"
  description = "Allows agent to access S3 documents bucket"
  policy      = data.aws_iam_policy_document.s3_documents.json

  tags = var.tags
}

data "aws_iam_policy_document" "s3_documents" {
  # List bucket contents
  statement {
    sid    = "ListDocumentsBucket"
    effect = "Allow"
    actions = [
      "s3:ListBucket",
      "s3:GetBucketLocation",
      "s3:ListBucketVersions"
    ]
    resources = var.documents_bucket_arns
  }

  # Read, write, and delete objects
  statement {
    sid    = "ManageDocuments"
    effect = "Allow"
    actions = [
      "s3:GetObject",
      "s3:GetObjectVersion",
      "s3:PutObject",
      "s3:DeleteObject",
      "s3:DeleteObjectVersion"
    ]
    resources = [for arn in var.documents_bucket_arns : "${arn}/*"]
  }

  # Get object metadata
  statement {
    sid    = "GetDocumentMetadata"
    effect = "Allow"
    actions = [
      "s3:GetObjectAttributes",
      "s3:GetObjectMetadata",
      "s3:HeadObject"
    ]
    resources = [for arn in var.documents_bucket_arns : "${arn}/*"]
  }
}

# Attach S3 documents policy to role
resource "aws_iam_role_policy_attachment" "s3_documents" {
  role       = aws_iam_role.agent.name
  policy_arn = aws_iam_policy.s3_documents.arn
}

# Policy for S3 Vectors access
resource "aws_iam_policy" "s3_vectors" {
  name        = "${local.role_name}-s3-vectors"
  description = "Allows agent to access S3 Vectors storage"
  policy      = data.aws_iam_policy_document.s3_vectors.json

  tags = var.tags
}

data "aws_iam_policy_document" "s3_vectors" {
  # List and manage vector buckets
  statement {
    sid    = "ListVectorBuckets"
    effect = "Allow"
    actions = [
      "s3vectors:ListVectorBuckets",
      "s3vectors:GetVectorBucket"
    ]
    resources = var.vectors_bucket_arns
  }

  # Manage vectors (put, get, delete)
  statement {
    sid    = "ManageVectors"
    effect = "Allow"
    actions = [
      "s3vectors:PutVector",
      "s3vectors:GetVector",
      "s3vectors:DeleteVector",
      "s3vectors:SearchVectors"
    ]
    resources = [for arn in var.vectors_bucket_arns : "${arn}/*"]
  }

  # Manage vector indexes
  statement {
    sid    = "ManageVectorIndexes"
    effect = "Allow"
    actions = [
      "s3vectors:DescribeVectorIndex",
      "s3vectors:QueryVectorIndex",
      "s3vectors:SearchVectorIndex"
    ]
    resources = length(var.vector_index_arns) > 0 ? var.vector_index_arns : ["${var.vectors_bucket_arns[0]}/*"]
  }
}

# Attach S3 vectors policy to role
resource "aws_iam_role_policy_attachment" "s3_vectors" {
  role       = aws_iam_role.agent.name
  policy_arn = aws_iam_policy.s3_vectors.arn
}

# Policy for Bedrock model invocation
resource "aws_iam_policy" "bedrock" {
  name        = "${local.role_name}-bedrock"
  description = "Allows agent to invoke Bedrock models"
  policy      = data.aws_iam_policy_document.bedrock.json

  tags = var.tags
}

data "aws_iam_policy_document" "bedrock" {
  # Invoke foundation models
  statement {
    sid    = "InvokeBedrockModels"
    effect = "Allow"
    actions = [
      "bedrock:InvokeModel",
      "bedrock:InvokeModelWithResponseStream"
    ]
    resources = var.bedrock_model_arns
  }

  # List available models (for discovery)
  statement {
    sid    = "ListBedrockModels"
    effect = "Allow"
    actions = [
      "bedrock:ListFoundationModels",
      "bedrock:GetFoundationModel"
    ]
    resources = ["*"]
  }

  # Agent-specific operations
  dynamic "statement" {
    for_each = var.enable_agent_operations ? [1] : []
    content {
      sid    = "AgentOperations"
      effect = "Allow"
      actions = [
        "bedrock:InvokeAgent",
        "bedrock:GetAgent",
        "bedrock:GetAgentVersion",
        "bedrock:GetAgentAlias"
      ]
      resources = ["arn:aws:bedrock:${data.aws_region.current.id}:${data.aws_caller_identity.current.account_id}:agent/*"]
    }
  }
}

# Attach Bedrock policy to role
resource "aws_iam_role_policy_attachment" "bedrock" {
  role       = aws_iam_role.agent.name
  policy_arn = aws_iam_policy.bedrock.arn
}

# Policy for CloudWatch Logs
resource "aws_iam_policy" "cloudwatch_logs" {
  name        = "${local.role_name}-cloudwatch-logs"
  description = "Allows agent to write logs to CloudWatch"
  policy      = data.aws_iam_policy_document.cloudwatch_logs.json

  tags = var.tags
}

data "aws_iam_policy_document" "cloudwatch_logs" {
  # Create log streams and write logs
  statement {
    sid    = "WriteCloudWatchLogs"
    effect = "Allow"
    actions = [
      "logs:CreateLogStream",
      "logs:PutLogEvents"
    ]
    resources = length(var.log_group_arns) > 0 ? var.log_group_arns : ["arn:aws:logs:${data.aws_region.current.id}:${data.aws_caller_identity.current.account_id}:log-group:/aws/bedrock/*:*"]
  }

  # Create log groups (if needed)
  statement {
    sid    = "CreateLogGroups"
    effect = "Allow"
    actions = [
      "logs:CreateLogGroup"
    ]
    resources = ["arn:aws:logs:${data.aws_region.current.id}:${data.aws_caller_identity.current.account_id}:log-group:/aws/bedrock/*"]
  }
}

# Attach CloudWatch Logs policy to role
resource "aws_iam_role_policy_attachment" "cloudwatch_logs" {
  role       = aws_iam_role.agent.name
  policy_arn = aws_iam_policy.cloudwatch_logs.arn
}

# Optional: Attach custom policies
resource "aws_iam_role_policy_attachment" "custom" {
  for_each = toset(var.additional_policy_arns)

  role       = aws_iam_role.agent.name
  policy_arn = each.value
}

# Optional: KMS key access for encryption
resource "aws_iam_policy" "kms" {
  count = length(var.kms_key_arns) > 0 ? 1 : 0

  name        = "${local.role_name}-kms"
  description = "Allows agent to use KMS keys for encryption/decryption"
  policy      = data.aws_iam_policy_document.kms[0].json

  tags = var.tags
}

data "aws_iam_policy_document" "kms" {
  count = length(var.kms_key_arns) > 0 ? 1 : 0

  statement {
    sid    = "UseKMSKeys"
    effect = "Allow"
    actions = [
      "kms:Decrypt",
      "kms:Encrypt",
      "kms:GenerateDataKey",
      "kms:DescribeKey"
    ]
    resources = var.kms_key_arns
  }
}

resource "aws_iam_role_policy_attachment" "kms" {
  count = length(var.kms_key_arns) > 0 ? 1 : 0

  role       = aws_iam_role.agent.name
  policy_arn = aws_iam_policy.kms[0].arn
}
