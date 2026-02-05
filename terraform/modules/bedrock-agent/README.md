# Bedrock Agent Module

Terraform module for creating and configuring Amazon Bedrock agents for RAG (Retrieval Augmented Generation) operations using AgentCore.

## Overview

This module provisions a complete Bedrock agent with action groups for:
- **Document Management**: Upload, list, and delete documents
- **Vector Search**: Semantic search through document embeddings

The agent is configured with Claude 3.5 Sonnet by default and integrates with S3 storage and S3 Vectors for the complete RAG workflow.

## Features

- ✅ **Pre-configured Agent**: Ready-to-use RAG agent with sensible defaults
- ✅ **Action Groups**: OpenAPI-defined actions for document management and search
- ✅ **Version Management**: Agent aliases for dev/staging/prod environments
- ✅ **Customizable Instructions**: Tailor agent behavior to your needs
- ✅ **Model Parameters**: Configurable temperature, top_p, max_tokens
- ✅ **Session Management**: Automatic idle timeout handling

## Usage

### Basic Usage

```hcl
module "bedrock_agent" {
  source = "../../modules/bedrock-agent"

  project_name     = "agentic-rag-demo"
  environment      = "dev"
  agent_role_arn   = module.iam_roles.role_arn

  # Lambda functions for action groups
  document_lambda_arn = aws_lambda_function.document_handler.arn
  search_lambda_arn   = aws_lambda_function.search_handler.arn

  # Foundation model
  foundation_model_id = "anthropic.claude-3-5-sonnet-20250110-v1:0"

  tags = {
    Project = "agentic-rag-demo"
    Team    = "AI/ML"
  }
}
```

### Production Configuration

```hcl
module "bedrock_agent" {
  source = "../../modules/bedrock-agent"

  project_name     = "agentic-rag-demo"
  environment      = "prod"
  agent_role_arn   = module.iam_roles.role_arn

  # Lambda functions
  document_lambda_arn = aws_lambda_function.document_handler.arn
  search_lambda_arn   = aws_lambda_function.search_handler.arn

  # Model configuration
  foundation_model_id     = "anthropic.claude-3-5-sonnet-20250110-v1:0"
  temperature             = 0.5  # Lower for more deterministic responses
  max_tokens              = 4096
  top_p                   = 0.95

  # Session management
  idle_session_ttl_seconds = 1800  # 30 minutes

  # Custom agent instructions
  agent_instruction = <<-EOT
    You are an enterprise-grade document assistant for the ${var.company_name} knowledge base.

    Provide accurate, professional responses with proper citations.
    Always verify information before responding.
    Maintain strict confidentiality and data privacy.
  EOT

  tags = {
    Project     = "agentic-rag-demo"
    Environment = "prod"
    Compliance  = "SOC2"
  }
}
```

### With Custom Prompt Override

```hcl
module "bedrock_agent" {
  source = "../../modules/bedrock-agent"

  project_name     = "agentic-rag-demo"
  environment      = "dev"
  agent_role_arn   = module.iam_roles.role_arn

  document_lambda_arn = aws_lambda_function.document_handler.arn
  search_lambda_arn   = aws_lambda_function.search_handler.arn

  # Enable prompt override
  enable_prompt_override   = true
  base_prompt_template     = file("${path.module}/prompts/custom-agent-prompt.txt")
  prompt_creation_mode     = "OVERRIDDEN"
  parser_mode              = "OVERRIDDEN"

  # Fine-tuned parameters
  temperature      = 0.3
  max_tokens       = 2048
  stop_sequences   = ["Human:", "Assistant:"]

  tags = {
    Project = "agentic-rag-demo"
  }
}
```

## Requirements

| Name | Version |
|------|---------|
| terraform | >= 1.5.0 |
| aws | ~> 5.0 |

## Providers

| Name | Version |
|------|---------|
| aws | ~> 5.0 |

## Inputs

### Required Inputs

| Name | Description | Type | Default |
|------|-------------|------|---------|
| project_name | Name of the project | `string` | n/a |
| environment | Environment (dev, staging, prod) | `string` | n/a |
| agent_role_arn | IAM role ARN for agent | `string` | n/a |
| document_lambda_arn | Lambda ARN for document operations | `string` | n/a |
| search_lambda_arn | Lambda ARN for search operations | `string` | n/a |

### Optional Inputs

| Name | Description | Type | Default |
|------|-------------|------|---------|
| foundation_model_id | Bedrock model ID | `string` | `"anthropic.claude-3-5-sonnet-20250110-v1:0"` |
| agent_instruction | Agent behavior instructions | `string` | Default RAG instructions |
| temperature | Sampling temperature (0-1) | `number` | `0.7` |
| max_tokens | Maximum tokens to generate | `number` | `2048` |
| top_p | Top P sampling | `number` | `0.9` |
| idle_session_ttl_seconds | Idle timeout in seconds | `number` | `600` |

See [variables.tf](./variables.tf) for complete list.

## Outputs

| Name | Description |
|------|-------------|
| agent_id | Bedrock agent ID |
| agent_arn | Bedrock agent ARN |
| agent_alias_id | Agent alias ID |
| agent_alias_arn | Agent alias ARN |
| agent_invocation_info | Info for invoking the agent |

See [outputs.tf](./outputs.tf) for complete list.

## Agent Action Groups

### 1. Document Management

**Purpose**: Handle document upload, listing, and deletion

**Operations**:
- `POST /documents/upload` - Upload and index a document
- `GET /documents/list` - List all documents
- `DELETE /documents/{documentId}` - Delete a document

**Lambda Handler Requirements**:
```python
def lambda_handler(event, context):
    # event contains:
    # - actionGroup: "document-management"
    # - function: "uploadDocument" | "listDocuments" | "deleteDocument"
    # - parameters: Request parameters

    action = event['function']

    if action == 'uploadDocument':
        # Process document upload
        # - Store in S3
        # - Generate embeddings
        # - Store vectors in S3 Vectors
        return {'document_id': 'uuid', 'status': 'success'}

    elif action == 'listDocuments':
        # List documents from S3
        return {'documents': [...]}

    elif action == 'deleteDocument':
        # Delete document and vectors
        return {'status': 'deleted'}
```

### 2. Vector Search

**Purpose**: Perform semantic search across documents

**Operations**:
- `POST /search` - Search for similar content

**Lambda Handler Requirements**:
```python
def lambda_handler(event, context):
    # event contains:
    # - actionGroup: "vector-search"
    # - function: "searchVectors"
    # - parameters: { query, top_k, filters }

    query = event['parameters']['query']
    top_k = event['parameters'].get('top_k', 5)

    # 1. Generate query embedding
    # 2. Search S3 Vectors
    # 3. Retrieve relevant chunks
    # 4. Return results with scores

    return {
        'results': [
            {
                'document_id': 'uuid',
                'chunk_text': 'Relevant content...',
                'similarity_score': 0.92,
                'metadata': {...}
            }
        ]
    }
```

## Foundation Models

### Supported Models

| Model ID | Context | Speed | Cost |
|----------|---------|-------|------|
| `anthropic.claude-3-5-sonnet-20250110-v1:0` | 200K | Fast | $$ |
| `anthropic.claude-3-opus-20240229` | 200K | Slow | $$$$ |
| `anthropic.claude-3-haiku-20240307` | 200K | Very Fast | $ |
| `amazon.titan-text-express-v1` | 8K | Fast | $ |

**Recommendation**: Claude 3.5 Sonnet provides the best balance of quality, speed, and cost for RAG applications.

### Model Selection Guide

**Development/Testing**:
- Use Claude 3 Haiku for faster iteration and lower costs
- Temperature: 0.7-0.9 for more creative responses

**Production**:
- Use Claude 3.5 Sonnet for optimal quality
- Temperature: 0.3-0.5 for more deterministic responses
- Implement caching for frequently asked questions

## Agent Instructions

### Default Instructions

The module includes sensible default instructions optimized for RAG:

```
You are a helpful AI assistant specializing in document management and retrieval.

Your capabilities include:
1. Accepting document uploads from users
2. Searching through documents to find relevant information
3. Answering questions based on document content
4. Managing the document collection

Always cite your sources and be accurate.
```

### Custom Instructions

Customize for your use case:

```hcl
agent_instruction = <<-EOT
  You are a ${var.company_name} knowledge assistant.

  Core responsibilities:
  - Help employees find internal documentation
  - Answer policy questions accurately
  - Provide step-by-step procedures when asked

  Guidelines:
  - Always cite document sources
  - If unsure, say "I don't have that information"
  - Use professional business language
  - Keep responses concise (2-3 paragraphs max)

  Compliance:
  - Never share confidential information externally
  - Follow data classification policies
  - Report security concerns to IT
EOT
```

## Cost Estimation

### Per Agent (Monthly)

**Development** (100 invocations/month):
- Agent: Free
- Model API calls: ~$2-5
- Lambda: ~$0.50
- **Total: ~$2.50-5.50/month**

**Production** (10,000 invocations/month):
- Agent: Free
- Model API calls: ~$200-500
- Lambda: ~$10-20
- **Total: ~$210-520/month**

### Cost Optimization

1. **Use Haiku for simple queries**: 5x cheaper than Sonnet
2. **Implement response caching**: Reduce duplicate API calls
3. **Optimize max_tokens**: Lower values reduce costs
4. **Batch operations**: Group Lambda invocations

## Troubleshooting

### Issue: Agent not responding

**Check**:
1. Agent status: `aws bedrock-agent get-agent --agent-id <id>`
2. Agent alias prepared: Check prepared_alias_arn output
3. Lambda function permissions: Agent role must invoke Lambdas
4. Action group configuration: Verify API schemas are valid

**Solution**:
```bash
# Re-prepare agent
terraform taint aws_bedrockagent_agent_alias.prepared_alias
terraform apply
```

### Issue: Action group errors

**Error**: `ActionGroupExecutionError`

**Common causes**:
1. Lambda function timeout (increase to 60s)
2. Lambda IAM permissions missing
3. Invalid API schema format
4. Lambda returning wrong format

**Debug**:
```bash
# Test Lambda directly
aws lambda invoke \
  --function-name <function-name> \
  --payload '{"function":"uploadDocument",...}' \
  response.json
```

### Issue: Model not accessible

**Error**: `ModelNotAccessibleException`

**Solution**:
1. Go to Bedrock console
2. Enable model access for your account
3. Wait for approval (usually instant)
4. Retry agent creation

### Issue: High latency

**Symptoms**: Slow agent responses

**Solutions**:
1. Reduce max_tokens (2048 → 1024)
2. Optimize Lambda cold starts (provisioned concurrency)
3. Use faster model (Haiku instead of Sonnet)
4. Implement caching layer

## Examples

### Complete Agent Setup

```hcl
# IAM role
module "iam_roles" {
  source = "../../modules/iam-roles"

  project_name           = "agentic-rag-demo"
  environment            = "dev"
  documents_bucket_arns  = [module.s3_storage.bucket_arn]
  vectors_bucket_arns    = [module.s3_vectors.vector_bucket_arn]
  vector_index_arns      = [module.s3_vectors.vector_index_arn]
  bedrock_model_arns     = ["*"]  # All models
}

# Lambda functions for action groups
resource "aws_lambda_function" "document_handler" {
  filename      = "document_handler.zip"
  function_name = "agentic-rag-demo-document-handler-dev"
  role          = aws_iam_role.lambda_role.arn
  handler       = "index.handler"
  runtime       = "python3.11"
  timeout       = 60

  environment {
    variables = {
      DOCUMENTS_BUCKET = module.s3_storage.bucket_id
      VECTORS_BUCKET   = module.s3_vectors.vector_bucket_name
    }
  }
}

resource "aws_lambda_function" "search_handler" {
  filename      = "search_handler.zip"
  function_name = "agentic-rag-demo-search-handler-dev"
  role          = aws_iam_role.lambda_role.arn
  handler       = "index.handler"
  runtime       = "python3.11"
  timeout       = 30

  environment {
    variables = {
      VECTORS_BUCKET = module.s3_vectors.vector_bucket_name
      VECTOR_INDEX   = module.s3_vectors.vector_index_name
    }
  }
}

# Bedrock agent
module "bedrock_agent" {
  source = "../../modules/bedrock-agent"

  project_name        = "agentic-rag-demo"
  environment         = "dev"
  agent_role_arn      = module.iam_roles.role_arn
  document_lambda_arn = aws_lambda_function.document_handler.arn
  search_lambda_arn   = aws_lambda_function.search_handler.arn
}

# Output for UI
output "agent_info" {
  value = module.bedrock_agent.agent_invocation_info
}
```

## Additional Resources

- [Amazon Bedrock Agents Documentation](https://docs.aws.amazon.com/bedrock/latest/userguide/agents.html)
- [Bedrock Model IDs](https://docs.aws.amazon.com/bedrock/latest/userguide/model-ids.html)
- [Agent Action Groups](https://docs.aws.amazon.com/bedrock/latest/userguide/agents-action-groups.html)

## License

MIT - See main repository LICENSE file

---

**Module Version**: 1.0.0
**Last Updated**: 2026-02-05
