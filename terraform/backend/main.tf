terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 6.24.0"
    }
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = var.project_name
      ManagedBy   = "terraform"
      Component   = "backend"
      Environment = "shared"
    }
  }
}

# Get current AWS account ID
data "aws_caller_identity" "current" {}

# Get current AWS region
data "aws_region" "current" {}

# S3 bucket for Terraform state
resource "aws_s3_bucket" "tfstate" {
  bucket = "${var.project_name}-tfstate-${data.aws_caller_identity.current.account_id}"

  tags = {
    Name        = "Terraform State Bucket"
    Description = "Stores Terraform state files for ${var.project_name}"
  }
}

# Enable versioning for state file recovery
resource "aws_s3_bucket_versioning" "tfstate" {
  bucket = aws_s3_bucket.tfstate.id

  versioning_configuration {
    status = "Enabled"
  }
}

# Enable server-side encryption
resource "aws_s3_bucket_server_side_encryption_configuration" "tfstate" {
  bucket = aws_s3_bucket.tfstate.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# Block all public access
resource "aws_s3_bucket_public_access_block" "tfstate" {
  bucket = aws_s3_bucket.tfstate.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Enable bucket logging (optional but recommended)
resource "aws_s3_bucket" "tfstate_logs" {
  bucket = "${var.project_name}-tfstate-logs-${data.aws_caller_identity.current.account_id}"

  tags = {
    Name        = "Terraform State Logs Bucket"
    Description = "Stores access logs for Terraform state bucket"
  }
}

resource "aws_s3_bucket_public_access_block" "tfstate_logs" {
  bucket = aws_s3_bucket.tfstate_logs.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_logging" "tfstate" {
  bucket = aws_s3_bucket.tfstate.id

  target_bucket = aws_s3_bucket.tfstate_logs.id
  target_prefix = "state-access-logs/"
}

# Lifecycle policy for state file versions
resource "aws_s3_bucket_lifecycle_configuration" "tfstate" {
  bucket = aws_s3_bucket.tfstate.id

  rule {
    id     = "expire-old-versions"
    status = "Enabled"

    noncurrent_version_expiration {
      noncurrent_days = var.state_version_retention_days
    }
  }

  rule {
    id     = "expire-old-logs"
    status = "Enabled"

    filter {
      prefix = "state-access-logs/"
    }

    expiration {
      days = var.log_retention_days
    }
  }
}

# DynamoDB table for state locking
resource "aws_dynamodb_table" "tfstate_lock" {
  name           = "${var.project_name}-tfstate-lock"
  billing_mode   = "PAY_PER_REQUEST"
  hash_key       = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }

  point_in_time_recovery {
    enabled = true
  }

  tags = {
    Name        = "Terraform State Lock Table"
    Description = "Provides state locking for ${var.project_name}"
  }
}

# KMS key for enhanced encryption (optional)
resource "aws_kms_key" "tfstate" {
  count = var.enable_kms_encryption ? 1 : 0

  description             = "KMS key for ${var.project_name} Terraform state encryption"
  deletion_window_in_days = 10
  enable_key_rotation     = true

  tags = {
    Name = "${var.project_name}-tfstate-key"
  }
}

resource "aws_kms_alias" "tfstate" {
  count = var.enable_kms_encryption ? 1 : 0

  name          = "alias/${var.project_name}-tfstate"
  target_key_id = aws_kms_key.tfstate[0].key_id
}

# Bucket policy to enforce encryption in transit
resource "aws_s3_bucket_policy" "tfstate" {
  bucket = aws_s3_bucket.tfstate.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "EnforceSSLOnly"
        Effect    = "Deny"
        Principal = "*"
        Action    = "s3:*"
        Resource = [
          aws_s3_bucket.tfstate.arn,
          "${aws_s3_bucket.tfstate.arn}/*"
        ]
        Condition = {
          Bool = {
            "aws:SecureTransport" = "false"
          }
        }
      }
    ]
  })
}
