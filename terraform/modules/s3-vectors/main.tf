# S3 Vectors Module for Vector Storage
# This module creates and configures S3 Vector Buckets for vector similarity search

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

# Generate bucket name with account ID for global uniqueness
locals {
  bucket_name = "${var.project_name}-vectors-${var.environment}-${data.aws_caller_identity.current.account_id}"
  index_name  = "${var.project_name}-index-${var.environment}"
}

# S3 Vector Bucket for storing vector embeddings
resource "aws_s3vectors_vector_bucket" "vectors" {
  vector_bucket_name = local.bucket_name

  tags = merge(
    var.tags,
    {
      Name        = local.bucket_name
      Environment = var.environment
      Purpose     = "Vector embeddings storage for RAG system"
    }
  )
}

# Vector Index for similarity search
resource "aws_s3vectors_index" "embeddings" {
  index_name         = local.index_name
  vector_bucket_name = aws_s3vectors_vector_bucket.vectors.vector_bucket_name

  # S3 Vectors currently only supports float32
  data_type = "float32"

  # Dimension of vectors
  dimension = var.vector_dimensions

  # Distance metric (cosine or euclidean only - map inner_product to cosine)
  distance_metric = var.distance_metric == "inner_product" ? "cosine" : var.distance_metric

  tags = merge(
    var.tags,
    {
      Name        = local.index_name
      Environment = var.environment
      Dimensions  = var.vector_dimensions
      Metric      = var.distance_metric
    }
  )
}

# IAM policy for agent access to vector bucket
resource "aws_iam_policy" "vector_bucket_access" {
  name        = "${local.bucket_name}-access"
  description = "Allows access to S3 Vector Bucket for ${var.project_name}"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "ListVectorBucket"
        Effect = "Allow"
        Action = [
          "s3vectors:ListVectorBuckets",
          "s3vectors:GetVectorBucket"
        ]
        Resource = aws_s3vectors_vector_bucket.vectors.vector_bucket_arn
      },
      {
        Sid    = "ManageVectors"
        Effect = "Allow"
        Action = [
          "s3vectors:PutVector",
          "s3vectors:GetVector",
          "s3vectors:DeleteVector",
          "s3vectors:SearchVectors"
        ]
        Resource = "${aws_s3vectors_vector_bucket.vectors.vector_bucket_arn}/*"
      },
      {
        Sid    = "ManageVectorIndex"
        Effect = "Allow"
        Action = [
          "s3vectors:DescribeVectorIndex",
          "s3vectors:QueryVectorIndex",
          "s3vectors:SearchVectorIndex"
        ]
        Resource = aws_s3vectors_index.embeddings.index_arn
      }
    ]
  })

  tags = var.tags
}

# Attach policy to agent roles
resource "aws_iam_role_policy_attachment" "vector_bucket_access" {
  for_each = toset(var.agent_role_names)

  role       = each.value
  policy_arn = aws_iam_policy.vector_bucket_access.arn
}

# CloudWatch alarm for vector count
resource "aws_cloudwatch_metric_alarm" "vector_count" {
  count = var.enable_count_alarm ? 1 : 0

  alarm_name          = "${local.bucket_name}-vector-count-alarm"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "VectorCount"
  namespace           = "AWS/S3Vectors"
  period              = 3600 # 1 hour
  statistic           = "Average"
  threshold           = var.vector_count_alarm_threshold
  alarm_description   = "Alert when vector count exceeds threshold"
  alarm_actions       = var.alarm_sns_topic_arns

  dimensions = {
    VectorBucketName = aws_s3vectors_vector_bucket.vectors.vector_bucket_name
  }

  tags = var.tags
}

# CloudWatch alarm for search latency
resource "aws_cloudwatch_metric_alarm" "search_latency" {
  count = var.enable_latency_alarm ? 1 : 0

  alarm_name          = "${local.bucket_name}-search-latency-alarm"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "SearchLatency"
  namespace           = "AWS/S3Vectors"
  period              = 300 # 5 minutes
  statistic           = "Average"
  threshold           = var.latency_alarm_threshold_ms
  alarm_description   = "Alert when vector search latency is high"
  alarm_actions       = var.alarm_sns_topic_arns

  dimensions = {
    VectorBucketName = aws_s3vectors_vector_bucket.vectors.vector_bucket_name
    VectorIndexName  = aws_s3vectors_index.embeddings.index_name
  }

  tags = var.tags
}

# Optional: Backup configuration for vector bucket
resource "aws_backup_selection" "vectors" {
  count = var.enable_backup ? 1 : 0

  iam_role_arn = var.backup_role_arn
  name         = "${local.bucket_name}-backup-selection"
  plan_id      = var.backup_plan_id

  resources = [
    aws_s3vectors_vector_bucket.vectors.vector_bucket_arn
  ]
}
