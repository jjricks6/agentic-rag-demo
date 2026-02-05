# Development Environment Outputs

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
  description = "Complete agent configuration for Streamlit UI"
  value = {
    # Agent
    agent_id              = module.bedrock_agent.agent_id
    agent_alias_id        = module.bedrock_agent.prepared_alias_id
    agent_arn             = module.bedrock_agent.agent_arn

    # Storage
    documents_bucket      = module.s3_storage.bucket_id
    vectors_bucket        = module.s3_vectors.vector_bucket_name
    vector_index          = module.s3_vectors.vector_index_name

    # Models
    llm_model             = var.llm_model_id
    embedding_model       = var.embedding_model_id

    # Vector config
    vector_dimensions     = var.vector_dimensions
    distance_metric       = var.distance_metric

    # AWS
    region                = local.region
    account_id            = local.account_id

    # Environment
    environment           = var.environment
  }
  sensitive = false
}

# ============================================================================
# Connection Commands
# ============================================================================

output "aws_console_links" {
  description = "Quick links to AWS console"
  value = {
    agent_console      = "https://${local.region}.console.aws.amazon.com/bedrock/home?region=${local.region}#/agents/${module.bedrock_agent.agent_id}"
    s3_documents       = "https://s3.console.aws.amazon.com/s3/buckets/${module.s3_storage.bucket_id}"
    cloudwatch_logs    = "https://${local.region}.console.aws.amazon.com/cloudwatch/home?region=${local.region}#logsV2:log-groups/log-group/${replace(module.cloudwatch_logs.log_group_name, "/", "$252F")}"
    cloudwatch_dashboard = module.cloudwatch_logs.dashboard_name != null ? "https://${local.region}.console.aws.amazon.com/cloudwatch/home?region=${local.region}#dashboards:name=${module.cloudwatch_logs.dashboard_name}" : "Not created"
  }
}

output "next_steps" {
  description = "What to do next after deployment"
  value = <<-EOT
    ✅ Development infrastructure deployed successfully!

    Next steps:
    1. Save agent config: terraform output -json agent_config > ../../agent-config-dev.json

    2. Build Lambda functions:
       cd ../../agent/lambda
       ./build.sh

    3. Update Lambda functions:
       cd ../terraform/environments/dev
       terraform apply -target=aws_lambda_function.document_handler -target=aws_lambda_function.search_handler

    4. Test agent:
       aws bedrock-agent-runtime invoke-agent \
         --agent-id ${module.bedrock_agent.agent_id} \
         --agent-alias-id ${module.bedrock_agent.prepared_alias_id} \
         --session-id test-session \
         --input-text "Hello, can you help me?"

    5. Run Streamlit UI:
       cd ../../ui/streamlit-app
       streamlit run app.py

    AWS Console Links:
    - Agent: ${local.region}.console.aws.amazon.com/bedrock/home?region=${local.region}#/agents/${module.bedrock_agent.agent_id}
    - Logs: ${local.region}.console.aws.amazon.com/cloudwatch/home?region=${local.region}#logsV2:log-groups
  EOT
}
