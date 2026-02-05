# IAM Role Outputs

output "role_arn" {
  description = "ARN of the IAM role for the agent"
  value       = aws_iam_role.agent.arn
}

output "role_name" {
  description = "Name of the IAM role"
  value       = aws_iam_role.agent.name
}

output "role_id" {
  description = "ID of the IAM role"
  value       = aws_iam_role.agent.id
}

output "role_unique_id" {
  description = "Stable and unique string identifying the role"
  value       = aws_iam_role.agent.unique_id
}

# Policy Outputs

output "s3_documents_policy_arn" {
  description = "ARN of the S3 documents access policy"
  value       = aws_iam_policy.s3_documents.arn
}

output "s3_vectors_policy_arn" {
  description = "ARN of the S3 vectors access policy"
  value       = aws_iam_policy.s3_vectors.arn
}

output "bedrock_policy_arn" {
  description = "ARN of the Bedrock invocation policy"
  value       = aws_iam_policy.bedrock.arn
}

output "cloudwatch_logs_policy_arn" {
  description = "ARN of the CloudWatch Logs policy"
  value       = aws_iam_policy.cloudwatch_logs.arn
}

output "kms_policy_arn" {
  description = "ARN of the KMS access policy (if created)"
  value       = length(var.kms_key_arns) > 0 ? aws_iam_policy.kms[0].arn : null
}

# Configuration Outputs

output "trusted_services" {
  description = "List of AWS services that can assume this role"
  value       = var.trusted_services
}

output "max_session_duration" {
  description = "Maximum session duration in seconds"
  value       = var.max_session_duration
}

# Permissions Summary

output "permissions_summary" {
  description = "Summary of permissions granted to this role"
  value = {
    s3_documents_buckets = var.documents_bucket_arns
    s3_vectors_buckets   = var.vectors_bucket_arns
    bedrock_models       = length(var.bedrock_model_arns) > 0 ? var.bedrock_model_arns : ["All models in account"]
    cloudwatch_logs      = length(var.log_group_arns) > 0 ? var.log_group_arns : ["/aws/bedrock/*"]
    kms_keys             = var.kms_key_arns
    agent_ops_enabled    = var.enable_agent_operations
  }
}
