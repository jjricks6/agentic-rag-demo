# S3 Storage Module for Document Storage
# This module creates and configures S3 buckets for storing documents

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

# Generate bucket name with account ID to ensure global uniqueness
locals {
  bucket_name = "${var.project_name}-${var.bucket_suffix}-${var.environment}-${data.aws_caller_identity.current.account_id}"
}

# S3 bucket for document storage
resource "aws_s3_bucket" "documents" {
  bucket = local.bucket_name

  # Allow destroy even if bucket contains objects (for dev/testing)
  force_destroy = var.force_destroy

  tags = merge(
    var.tags,
    {
      Name        = local.bucket_name
      Environment = var.environment
      Purpose     = "Document storage for RAG system"
    }
  )
}

# Enable versioning for document recovery
resource "aws_s3_bucket_versioning" "documents" {
  count  = var.enable_versioning ? 1 : 0
  bucket = aws_s3_bucket.documents.id

  versioning_configuration {
    status = "Enabled"
  }
}

# Server-side encryption configuration
resource "aws_s3_bucket_server_side_encryption_configuration" "documents" {
  bucket = aws_s3_bucket.documents.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = var.kms_key_id != null ? "aws:kms" : "AES256"
      kms_master_key_id = var.kms_key_id
    }
    bucket_key_enabled = var.kms_key_id != null ? true : false
  }
}

# Block all public access
resource "aws_s3_bucket_public_access_block" "documents" {
  bucket = aws_s3_bucket.documents.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Lifecycle configuration for cost optimization
resource "aws_s3_bucket_lifecycle_configuration" "documents" {
  count  = var.enable_lifecycle_rules ? 1 : 0
  bucket = aws_s3_bucket.documents.id

  # Delete old document versions
  dynamic "rule" {
    for_each = var.enable_versioning ? [1] : []
    content {
      id     = "delete-old-versions"
      status = "Enabled"

      noncurrent_version_expiration {
        noncurrent_days = var.noncurrent_version_retention_days
      }
    }
  }

  # Transition documents to Glacier for archival
  dynamic "rule" {
    for_each = var.enable_glacier_transition ? [1] : []
    content {
      id     = "transition-to-glacier"
      status = "Enabled"

      transition {
        days          = var.glacier_transition_days
        storage_class = "GLACIER"
      }

      filter {
        prefix = var.glacier_transition_prefix
      }
    }
  }

  # Delete incomplete multipart uploads
  rule {
    id     = "delete-incomplete-uploads"
    status = "Enabled"

    abort_incomplete_multipart_upload {
      days_after_initiation = var.abort_incomplete_multipart_upload_days
    }
  }
}

# CORS configuration for web uploads
resource "aws_s3_bucket_cors_configuration" "documents" {
  count  = var.enable_cors ? 1 : 0
  bucket = aws_s3_bucket.documents.id

  cors_rule {
    allowed_headers = var.cors_allowed_headers
    allowed_methods = var.cors_allowed_methods
    allowed_origins = var.cors_allowed_origins
    expose_headers  = var.cors_expose_headers
    max_age_seconds = var.cors_max_age_seconds
  }
}

# Bucket policy for secure access
resource "aws_s3_bucket_policy" "documents" {
  bucket = aws_s3_bucket.documents.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      # Enforce SSL/TLS for all requests
      {
        Sid       = "EnforceSSLOnly"
        Effect    = "Deny"
        Principal = "*"
        Action    = "s3:*"
        Resource = [
          aws_s3_bucket.documents.arn,
          "${aws_s3_bucket.documents.arn}/*"
        ]
        Condition = {
          Bool = {
            "aws:SecureTransport" = "false"
          }
        }
      },
      # Allow agent role to access documents
      {
        Sid    = "AllowAgentAccess"
        Effect = "Allow"
        Principal = {
          AWS = var.agent_role_arns
        }
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:ListBucket"
        ]
        Resource = [
          aws_s3_bucket.documents.arn,
          "${aws_s3_bucket.documents.arn}/*"
        ]
      }
    ]
  })
}

# Bucket notification for event-driven processing (optional)
resource "aws_s3_bucket_notification" "documents" {
  count  = length(var.notification_lambda_arns) > 0 ? 1 : 0
  bucket = aws_s3_bucket.documents.id

  dynamic "lambda_function" {
    for_each = var.notification_lambda_arns
    content {
      lambda_function_arn = lambda_function.value
      events              = ["s3:ObjectCreated:*"]
      filter_prefix       = var.notification_filter_prefix
      filter_suffix       = var.notification_filter_suffix
    }
  }
}

# CloudWatch metric alarm for bucket size (optional)
resource "aws_cloudwatch_metric_alarm" "bucket_size" {
  count = var.enable_size_alarm ? 1 : 0

  alarm_name          = "${local.bucket_name}-size-alarm"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "BucketSizeBytes"
  namespace           = "AWS/S3"
  period              = 86400 # 1 day
  statistic           = "Average"
  threshold           = var.size_alarm_threshold_bytes
  alarm_description   = "Alert when S3 bucket size exceeds threshold"
  alarm_actions       = var.alarm_sns_topic_arns

  dimensions = {
    BucketName  = aws_s3_bucket.documents.id
    StorageType = "StandardStorage"
  }

  tags = var.tags
}
