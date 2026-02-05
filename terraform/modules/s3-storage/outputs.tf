# S3 Bucket Outputs

output "bucket_id" {
  description = "The name of the S3 bucket"
  value       = aws_s3_bucket.documents.id
}

output "bucket_arn" {
  description = "The ARN of the S3 bucket"
  value       = aws_s3_bucket.documents.arn
}

output "bucket_domain_name" {
  description = "The bucket domain name"
  value       = aws_s3_bucket.documents.bucket_domain_name
}

output "bucket_regional_domain_name" {
  description = "The bucket regional domain name"
  value       = aws_s3_bucket.documents.bucket_regional_domain_name
}

output "bucket_region" {
  description = "The AWS region where the bucket is located"
  value       = aws_s3_bucket.documents.region
}

# Versioning

output "versioning_enabled" {
  description = "Whether versioning is enabled on the bucket"
  value       = var.enable_versioning
}

# Encryption

output "encryption_algorithm" {
  description = "The encryption algorithm used for the bucket"
  value       = var.kms_key_id != null ? "aws:kms" : "AES256"
}

output "kms_key_id" {
  description = "The KMS key ID used for encryption (if applicable)"
  value       = var.kms_key_id
}

# CORS

output "cors_enabled" {
  description = "Whether CORS is enabled on the bucket"
  value       = var.enable_cors
}

# Monitoring

output "size_alarm_arn" {
  description = "ARN of the CloudWatch alarm for bucket size (if enabled)"
  value       = var.enable_size_alarm ? aws_cloudwatch_metric_alarm.bucket_size[0].arn : null
}

# Access Configuration

output "agent_role_arns" {
  description = "List of IAM role ARNs with access to this bucket"
  value       = var.agent_role_arns
}
