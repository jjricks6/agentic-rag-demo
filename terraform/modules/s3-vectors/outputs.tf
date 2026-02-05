# S3 Vector Bucket Outputs

output "vector_bucket_name" {
  description = "The name of the S3 Vector Bucket"
  value       = aws_s3vectors_vector_bucket.vectors.vector_bucket_name
}

output "vector_bucket_arn" {
  description = "The ARN of the S3 Vector Bucket"
  value       = aws_s3vectors_vector_bucket.vectors.vector_bucket_arn
}

# Vector Index Outputs

output "vector_index_name" {
  description = "The name of the vector index"
  value       = aws_s3vectors_index.embeddings.index_name
}

output "vector_index_arn" {
  description = "The ARN of the vector index"
  value       = aws_s3vectors_index.embeddings.index_arn
}

# Vector Configuration Outputs

output "vector_dimensions" {
  description = "Number of dimensions for vector embeddings"
  value       = var.vector_dimensions
}

output "distance_metric" {
  description = "Distance metric used for vector similarity"
  value       = var.distance_metric
}

# IAM Policy Outputs

output "vector_bucket_access_policy_arn" {
  description = "ARN of the IAM policy for vector bucket access"
  value       = aws_iam_policy.vector_bucket_access.arn
}

output "vector_bucket_access_policy_name" {
  description = "ARN of the IAM policy for vector bucket access"
  value       = aws_iam_policy.vector_bucket_access.name
}

# Monitoring Outputs

output "vector_count_alarm_arn" {
  description = "ARN of the CloudWatch alarm for vector count (if enabled)"
  value       = var.enable_count_alarm ? aws_cloudwatch_metric_alarm.vector_count[0].arn : null
}

output "search_latency_alarm_arn" {
  description = "ARN of the CloudWatch alarm for search latency (if enabled)"
  value       = var.enable_latency_alarm ? aws_cloudwatch_metric_alarm.search_latency[0].arn : null
}

# Access Configuration

output "agent_role_names" {
  description = "List of IAM role names with access to vector storage"
  value       = var.agent_role_names
}

# Connection Information (for agent configuration)

output "vector_store_config" {
  description = "Complete configuration for connecting to vector storage"
  value = {
    bucket_name       = aws_s3vectors_vector_bucket.vectors.vector_bucket_name
    bucket_arn        = aws_s3vectors_vector_bucket.vectors.vector_bucket_arn
    index_name        = aws_s3vectors_index.embeddings.index_name
    index_arn         = aws_s3vectors_index.embeddings.index_arn
    vector_dimensions = var.vector_dimensions
    distance_metric   = var.distance_metric
  }
}

# Backup Configuration

output "backup_enabled" {
  description = "Whether AWS Backup is enabled for the vector bucket"
  value       = var.enable_backup
}
