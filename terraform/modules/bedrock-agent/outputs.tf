# Bedrock Agent Outputs

output "agent_id" {
  description = "The unique identifier of the Bedrock agent"
  value       = aws_bedrockagent_agent.rag_agent.id
}

output "agent_arn" {
  description = "The ARN of the Bedrock agent"
  value       = aws_bedrockagent_agent.rag_agent.agent_arn
}

output "agent_name" {
  description = "The name of the Bedrock agent"
  value       = aws_bedrockagent_agent.rag_agent.agent_name
}

output "agent_version" {
  description = "The version of the Bedrock agent"
  value       = aws_bedrockagent_agent.rag_agent.agent_version
}

# Agent Alias Outputs

output "agent_alias_id" {
  description = "The ID of the agent alias"
  value       = aws_bedrockagent_agent_alias.agent_alias.id
}

output "agent_alias_arn" {
  description = "The ARN of the agent alias"
  value       = aws_bedrockagent_agent_alias.agent_alias.agent_alias_arn
}

output "agent_alias_name" {
  description = "The name of the agent alias"
  value       = aws_bedrockagent_agent_alias.agent_alias.agent_alias_name
}

output "prepared_alias_id" {
  description = "The ID of the prepared agent alias"
  value       = aws_bedrockagent_agent_alias.prepared_alias.id
}

output "prepared_alias_arn" {
  description = "The ARN of the prepared agent alias"
  value       = aws_bedrockagent_agent_alias.prepared_alias.agent_alias_arn
}

# Action Group Outputs

output "document_management_action_group_id" {
  description = "The ID of the document management action group"
  value       = aws_bedrockagent_agent_action_group.document_management.id
}

output "vector_search_action_group_id" {
  description = "The ID of the vector search action group"
  value       = aws_bedrockagent_agent_action_group.vector_search.id
}

# Configuration Outputs

output "foundation_model_id" {
  description = "The foundation model ID used by the agent"
  value       = var.foundation_model_id
}

output "agent_role_arn" {
  description = "The IAM role ARN used by the agent"
  value       = var.agent_role_arn
}

output "idle_session_ttl_seconds" {
  description = "The idle session timeout in seconds"
  value       = var.idle_session_ttl_seconds
}

# Model Parameters

output "model_parameters" {
  description = "Model parameters configuration"
  value = {
    max_tokens   = var.max_tokens
    temperature  = var.temperature
    top_p        = var.top_p
  }
}

# Invocation Information

output "agent_invocation_info" {
  description = "Information needed to invoke the agent"
  value = {
    agent_id         = aws_bedrockagent_agent.rag_agent.id
    agent_alias_id   = aws_bedrockagent_agent_alias.prepared_alias.id
    agent_alias_arn  = aws_bedrockagent_agent_alias.prepared_alias.agent_alias_arn
  }
}

# Full Agent Configuration (for debugging/reference)

output "agent_config" {
  description = "Complete agent configuration details"
  value = {
    name                        = aws_bedrockagent_agent.rag_agent.agent_name
    id                          = aws_bedrockagent_agent.rag_agent.id
    arn                         = aws_bedrockagent_agent.rag_agent.agent_arn
    version                     = aws_bedrockagent_agent.rag_agent.agent_version
    foundation_model            = var.foundation_model_id
    role_arn                    = var.agent_role_arn
    alias_id                    = aws_bedrockagent_agent_alias.prepared_alias.id
    alias_arn                   = aws_bedrockagent_agent_alias.prepared_alias.agent_alias_arn
    environment                 = var.environment
    idle_session_ttl            = var.idle_session_ttl_seconds
    document_management_group   = aws_bedrockagent_agent_action_group.document_management.id
    vector_search_group         = aws_bedrockagent_agent_action_group.vector_search.id
  }
}
