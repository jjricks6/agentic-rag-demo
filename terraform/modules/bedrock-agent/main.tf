# Bedrock Agent Module for AgentCore
# This module creates and configures a Bedrock agent for RAG operations

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

# Generate agent name
locals {
  agent_name        = "${var.project_name}-agent-${var.environment}"
  agent_alias_name  = var.environment
  agent_description = "Bidirectional RAG agent for ${var.project_name} - ${var.environment} environment"
}

# Bedrock Agent
resource "aws_bedrockagent_agent" "rag_agent" {
  agent_name              = local.agent_name
  agent_resource_role_arn = var.agent_role_arn
  foundation_model        = var.foundation_model_id
  description             = local.agent_description

  instruction = var.agent_instruction

  # Idle session timeout
  idle_session_ttl_in_seconds = var.idle_session_ttl_seconds

  # Prompt override configuration
  dynamic "prompt_override_configuration" {
    for_each = var.enable_prompt_override ? [1] : []
    content {
      prompt_configurations {
        base_prompt_template = var.base_prompt_template
        inference_configuration {
          max_length   = var.max_tokens
          temperature      = var.temperature
          top_p            = var.top_p
          stop_sequences   = var.stop_sequences
        }
        parser_mode        = var.parser_mode
        prompt_creation_mode = var.prompt_creation_mode
        prompt_state       = var.prompt_state
        prompt_type        = "ORCHESTRATION"
      }
    }
  }

  # Tags
  tags = merge(
    var.tags,
    {
      Name        = local.agent_name
      Environment = var.environment
      Purpose     = "RAG Agent"
    }
  )

}

# Agent Alias for versioning
resource "aws_bedrockagent_agent_alias" "agent_alias" {
  agent_alias_name = local.agent_alias_name
  agent_id         = aws_bedrockagent_agent.rag_agent.id
  description      = "Alias for ${var.environment} environment"

  # Routing configuration for version management
  dynamic "routing_configuration" {
    for_each = var.agent_version != null ? [1] : []
    content {
      agent_version = var.agent_version
    }
  }

  tags = var.tags
}

# Action Group for Document Management
resource "aws_bedrockagent_agent_action_group" "document_management" {
  action_group_name          = "document-management"
  agent_id                   = aws_bedrockagent_agent.rag_agent.id
  agent_version              = var.agent_version != null ? var.agent_version : "DRAFT"
  description                = "Actions for managing documents in S3"
  skip_resource_in_use_check = var.skip_resource_in_use_check
  prepare_agent              = false  # Don't prepare agent yet - will prepare after all action groups are added

  action_group_executor {
    lambda = var.document_lambda_arn
  }

  # API Schema for document operations
  api_schema {
    payload = jsonencode({
      openapi = "3.0.0"
      info = {
        title   = "Document Management API"
        version = "1.0.0"
      }
      paths = {
        "/documents/upload" = {
          post = {
            summary     = "Upload a document to S3"
            description = "Uploads a document to S3 storage for embedding and indexing"
            operationId = "uploadDocument"
            requestBody = {
              required = true
              content = {
                "application/json" = {
                  schema = {
                    type = "object"
                    properties = {
                      filename = {
                        type        = "string"
                        description = "Name of the document file"
                      }
                      content = {
                        type        = "string"
                        description = "Base64 encoded document content"
                      }
                      metadata = {
                        type        = "object"
                        description = "Additional metadata for the document"
                      }
                    }
                    required = ["filename", "content"]
                  }
                }
              }
            }
            responses = {
              "200" = {
                description = "Document uploaded successfully"
                content = {
                  "application/json" = {
                    schema = {
                      type = "object"
                      properties = {
                        document_id = {
                          type        = "string"
                          description = "Unique identifier for the document"
                        }
                        status = {
                          type = "string"
                        }
                      }
                    }
                  }
                }
              }
            }
          }
        }
        "/documents/list" = {
          get = {
            summary     = "List all documents"
            description = "Retrieves a list of all documents in storage"
            operationId = "listDocuments"
            responses = {
              "200" = {
                description = "List of documents"
                content = {
                  "application/json" = {
                    schema = {
                      type = "object"
                      properties = {
                        documents = {
                          type = "array"
                          items = {
                            type = "object"
                            properties = {
                              document_id = { type = "string" }
                              filename    = { type = "string" }
                              upload_date = { type = "string" }
                            }
                          }
                        }
                      }
                    }
                  }
                }
              }
            }
          }
        }
        "/documents/{documentId}" = {
          delete = {
            summary     = "Delete a document"
            description = "Deletes a document and its embeddings"
            operationId = "deleteDocument"
            parameters = [
              {
                name        = "documentId"
                in          = "path"
                required    = true
                description = "ID of the document to delete"
                schema = {
                  type = "string"
                }
              }
            ]
            responses = {
              "200" = {
                description = "Document deleted successfully"
              }
            }
          }
        }
      }
    })
  }

}

# Action Group for Vector Search
resource "aws_bedrockagent_agent_action_group" "vector_search" {
  action_group_name          = "vector-search"
  agent_id                   = aws_bedrockagent_agent.rag_agent.id
  agent_version              = var.agent_version != null ? var.agent_version : "DRAFT"
  description                = "Actions for searching vectors and retrieving context"
  skip_resource_in_use_check = var.skip_resource_in_use_check
  prepare_agent              = false  # Don't prepare agent yet - will prepare after all action groups are added

  action_group_executor {
    lambda = var.search_lambda_arn
  }

  # Wait for document management action group to complete
  depends_on = [aws_bedrockagent_agent_action_group.document_management]

  # API Schema for vector search operations
  api_schema {
    payload = jsonencode({
      openapi = "3.0.0"
      info = {
        title   = "Vector Search API"
        version = "1.0.0"
      }
      paths = {
        "/search" = {
          post = {
            summary     = "Search for similar vectors"
            description = "Performs vector similarity search to find relevant document chunks"
            operationId = "searchVectors"
            requestBody = {
              required = true
              content = {
                "application/json" = {
                  schema = {
                    type = "object"
                    properties = {
                      query = {
                        type        = "string"
                        description = "The search query text"
                      }
                      top_k = {
                        type        = "integer"
                        description = "Number of results to return"
                        default     = 5
                      }
                      filters = {
                        type        = "object"
                        description = "Optional filters for the search"
                      }
                    }
                    required = ["query"]
                  }
                }
              }
            }
            responses = {
              "200" = {
                description = "Search results"
                content = {
                  "application/json" = {
                    schema = {
                      type = "object"
                      properties = {
                        results = {
                          type = "array"
                          items = {
                            type = "object"
                            properties = {
                              document_id    = { type = "string" }
                              chunk_text     = { type = "string" }
                              similarity_score = { type = "number" }
                              metadata       = { type = "object" }
                            }
                          }
                        }
                      }
                    }
                  }
                }
              }
            }
          }
        }
      }
    })
  }

}

# Wait for agent to finish processing after action groups are added
resource "null_resource" "wait_for_agent_ready" {
  depends_on = [
    aws_bedrockagent_agent_action_group.document_management,
    aws_bedrockagent_agent_action_group.vector_search
  ]

  provisioner "local-exec" {
    command = <<-EOT
      echo "⏳ Waiting for agent to finish processing action groups..."
      for i in {1..40}; do
        STATUS=$(aws bedrock-agent get-agent \
          --agent-id ${aws_bedrockagent_agent.rag_agent.id} \
          --region ${data.aws_region.current.id} \
          --query 'agent.agentStatus' \
          --output text 2>/dev/null || echo "ERROR")

        if [ "$STATUS" = "PREPARED" ] || [ "$STATUS" = "NOT_PREPARED" ]; then
          echo "✅ Agent is ready for alias creation (status: $STATUS)"
          exit 0
        fi

        echo "   Waiting... (attempt $i/40, current status: $STATUS)"
        sleep 5
      done

      echo "⚠️  Timeout reached, proceeding anyway"
      exit 0
    EOT
  }

  triggers = {
    agent_id = aws_bedrockagent_agent.rag_agent.id
    action_groups = join(",", [
      aws_bedrockagent_agent_action_group.document_management.id,
      aws_bedrockagent_agent_action_group.vector_search.id
    ])
  }
}

# Prepare agent (required before use)
resource "aws_bedrockagent_agent_alias" "prepared_alias" {
  depends_on = [
    null_resource.wait_for_agent_ready
  ]

  agent_alias_name = "${local.agent_alias_name}-prepared"
  agent_id         = aws_bedrockagent_agent.rag_agent.id
  description      = "Prepared agent alias with all action groups"

  tags = var.tags
}
