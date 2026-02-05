# Production Environment Outputs

# ============================================================================
# Agent Information
# ============================================================================

output "agent_id" {
  description = "Bedrock agent ID"
  value       = module.bedrock_agent.agent_id
}

output "agent_arn" {
  description = "Bedrock agent ARN"
  value       = module.bedrock_agent.agent_arn
}

output "agent_alias_id" {
  description = "Agent alias ID for invocation"
  value       = module.bedrock_agent.prepared_alias_id
}

output "agent_alias_arn" {
  description = "Agent alias ARN for invocation"
  value       = module.bedrock_agent.prepared_alias_arn
}

# ============================================================================
# Storage Information
# ============================================================================

output "documents_bucket_name" {
  description = "S3 bucket name for documents"
  value       = module.s3_storage.bucket_id
}

output "documents_bucket_arn" {
  description = "S3 bucket ARN for documents"
  value       = module.s3_storage.bucket_arn
}

output "vectors_bucket_name" {
  description = "S3 Vectors bucket name"
  value       = module.s3_vectors.vector_bucket_name
}

output "vector_index_name" {
  description = "S3 Vectors index name"
  value       = module.s3_vectors.vector_index_name
}

# ============================================================================
# IAM Information
# ============================================================================

output "agent_role_arn" {
  description = "IAM role ARN for the agent"
  value       = module.iam_roles.role_arn
}

output "agent_role_name" {
  description = "IAM role name for the agent"
  value       = module.iam_roles.role_name
}

# ============================================================================
# Lambda Functions
# ============================================================================

output "document_handler_function_name" {
  description = "Lambda function name for document management"
  value       = aws_lambda_function.document_handler.function_name
}

output "search_handler_function_name" {
  description = "Lambda function name for vector search"
  value       = aws_lambda_function.search_handler.function_name
}

# ============================================================================
# Monitoring
# ============================================================================

output "log_group_name" {
  description = "CloudWatch log group name"
  value       = module.cloudwatch_logs.log_group_name
}

output "dashboard_name" {
  description = "CloudWatch dashboard name"
  value       = module.cloudwatch_logs.dashboard_name
}

# ============================================================================
# Configuration Summary (for UI/Agent)
# ============================================================================

output "agent_config" {
  description = "Complete agent configuration for production UI"
  value = {
    agent_id              = module.bedrock_agent.agent_id
    agent_alias_id        = module.bedrock_agent.prepared_alias_id
    agent_arn             = module.bedrock_agent.agent_arn
    documents_bucket      = module.s3_storage.bucket_id
    vectors_bucket        = module.s3_vectors.vector_bucket_name
    vector_index          = module.s3_vectors.vector_index_name
    llm_model             = var.llm_model_id
    embedding_model       = var.embedding_model_id
    vector_dimensions     = var.vector_dimensions
    distance_metric       = var.distance_metric
    region                = local.region
    account_id            = local.account_id
    environment           = var.environment
  }
  sensitive = false
}

# ============================================================================
# AWS Console Links
# ============================================================================

output "aws_console_links" {
  description = "Quick links to AWS console"
  value = {
    agent_console        = "https://${local.region}.console.aws.amazon.com/bedrock/home?region=${local.region}#/agents/${module.bedrock_agent.agent_id}"
    s3_documents         = "https://s3.console.aws.amazon.com/s3/buckets/${module.s3_storage.bucket_id}"
    s3_vectors           = "https://s3.console.aws.amazon.com/s3/buckets/${module.s3_vectors.vector_bucket_name}"
    cloudwatch_logs      = "https://${local.region}.console.aws.amazon.com/cloudwatch/home?region=${local.region}#logsV2:log-groups/log-group/${replace(module.cloudwatch_logs.log_group_name, "/", "$252F")}"
    cloudwatch_dashboard = module.cloudwatch_logs.dashboard_name != null ? "https://${local.region}.console.aws.amazon.com/cloudwatch/home?region=${local.region}#dashboards:name=${module.cloudwatch_logs.dashboard_name}" : "Not created"
  }
}

# ============================================================================
# Production Deployment Summary
# ============================================================================

output "deployment_summary" {
  description = "Production deployment summary"
  value = <<-EOT
    ✅ Production infrastructure deployed successfully!

    ⚠️  IMPORTANT PRODUCTION NOTES:
    1. Verify all CloudWatch alarms are configured
    2. Confirm SNS topic subscriptions for alerts
    3. Test agent thoroughly before exposing to users
    4. Monitor costs closely in first week
    5. Set up billing alarms if not already configured

    Agent Information:
    - Agent ID: ${module.bedrock_agent.agent_id}
    - Alias ID: ${module.bedrock_agent.prepared_alias_id}

    Storage:
    - Documents: ${module.s3_storage.bucket_id}
    - Vectors: ${module.s3_vectors.vector_bucket_name}

    Monitoring:
    - Dashboard: ${module.cloudwatch_logs.dashboard_name}
    - Log Group: ${module.cloudwatch_logs.log_group_name}

    Next steps:
    1. Save config: terraform output -json agent_config > ../../agent-config-prod.json
    2. Update Lambda functions with production code
    3. Run integration tests
    4. Monitor CloudWatch dashboard
    5. Review and respond to any alarms
  EOT
}
