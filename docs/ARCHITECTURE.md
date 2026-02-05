# Architecture Documentation

## Table of Contents
1. [System Overview](#system-overview)
2. [Architecture Diagram](#architecture-diagram)
3. [Component Details](#component-details)
4. [Data Flow](#data-flow)
5. [Design Decisions](#design-decisions)
6. [Security Architecture](#security-architecture)
7. [Scalability & Performance](#scalability--performance)
8. [Cost Optimization](#cost-optimization)

## System Overview

The Agentic RAG Demo implements a bidirectional Retrieval Augmented Generation (RAG) system that enables users to:
- Upload and manage documents through a conversational AI agent
- Query the knowledge base using natural language
- Receive contextually relevant answers with source attribution

### Core Principles
- **Serverless-First**: No infrastructure management, pay-per-use
- **AWS-Native**: Leverage managed services for reliability and scalability
- **Cost-Optimized**: On-demand pricing with no idle resources
- **Security-Focused**: Least privilege access, encryption at rest
- **Infrastructure as Code**: Complete reproducibility with Terraform

## Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────┐
│                         User Interface                           │
│                     (Streamlit Web UI)                           │
└────────────────────────────┬────────────────────────────────────┘
                             │
                             │ HTTPS
                             │
┌────────────────────────────▼────────────────────────────────────┐
│                      AgentCore Runtime                           │
│                    (Strands Agent)                               │
│                                                                   │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │ Agent Tools:                                              │  │
│  │  - S3 Document Manager                                   │  │
│  │  - Bedrock Embeddings Client                             │  │
│  │  - S3 Vectors Search Client                              │  │
│  └──────────────────────────────────────────────────────────┘  │
└─────────┬──────────────────┬──────────────────┬────────────────┘
          │                  │                  │
          │                  │                  │
┌─────────▼─────────┐ ┌─────▼──────────┐ ┌────▼───────────────┐
│                   │ │                 │ │                    │
│   Amazon S3       │ │ Amazon Bedrock  │ │   S3 Vectors       │
│                   │ │                 │ │                    │
│ ┌───────────────┐ │ │ ┌─────────────┐ │ │ ┌────────────────┐ │
│ │  Documents    │ │ │ │ Titan       │ │ │ │ Vector Store   │ │
│ │  Storage      │ │ │ │ Embeddings  │ │ │ │                │ │
│ └───────────────┘ │ │ └─────────────┘ │ │ └────────────────┘ │
│                   │ │                 │ │                    │
│ ┌───────────────┐ │ │ ┌─────────────┐ │ │ ┌────────────────┐ │
│ │  Metadata     │ │ │ │ Claude      │ │ │ │ Embeddings     │ │
│ │  Storage      │ │ │ │ (LLM)       │ │ │ │ Index          │ │
│ └───────────────┘ │ │ └─────────────┘ │ │ └────────────────┘ │
│                   │ │                 │ │                    │
└───────────────────┘ └─────────────────┘ └────────────────────┘
          │                                          │
          │                                          │
┌─────────▼──────────────────────────────────────────▼───────────┐
│                    CloudWatch Logs                              │
│              (Monitoring & Observability)                       │
└─────────────────────────────────────────────────────────────────┘
```

## Component Details

### 1. Streamlit Web UI

**Purpose**: User-facing interface for document upload and chat interactions

**Technology**: Python Streamlit application

**Features**:
- Document upload widget (PDF, DOCX, TXT, MD)
- Chat interface with message history
- Real-time agent response streaming
- Source document attribution
- Simple, clean UI optimized for demos

**Deployment**:
- Development: Local execution (`streamlit run app.py`)
- Production: AWS-IA Serverless Streamlit module on ECS Fargate

### 2. AgentCore Runtime (Strands Agent)

**Purpose**: Orchestrates all RAG operations and tool execution

**Technology**: Strands Agent Framework deployed to AWS AgentCore

**Responsibilities**:
- Parse user intents (upload vs. query)
- Coordinate document processing pipeline
- Execute vector similarity searches
- Generate contextual responses
- Manage conversation state

**Agent Tools**:

#### S3 Document Manager Tool
- Upload documents to S3
- Generate unique document IDs
- Store metadata (filename, upload timestamp, chunk count)
- List and retrieve documents
- Delete documents (with vector cleanup)

#### Bedrock Embeddings Client Tool
- Generate embeddings for document chunks
- Generate embeddings for user queries
- Handle batching for large documents
- Retry logic for rate limits

#### S3 Vectors Search Client Tool
- Execute k-NN vector searches
- Return top-k similar chunks with scores
- Metadata filtering support
- Handle search errors gracefully

**Configuration**:
```python
Agent Configuration:
- Model: Claude 3.5 Sonnet (via Bedrock)
- Temperature: 0.7
- Max Tokens: 4096
- System Prompt: Includes RAG instructions and tool usage guidance
```

### 3. Amazon S3 Storage

**Purpose**: Durable storage for documents and metadata

**Bucket Structure**:
```
s3://{project}-documents-{env}-{account-id}/
├── documents/
│   ├── {doc-id}/
│   │   ├── original.{ext}        # Original uploaded file
│   │   └── metadata.json         # Document metadata
│   └── ...
└── logs/                         # S3 access logs (optional)
```

**Metadata Schema**:
```json
{
  "document_id": "uuid-v4",
  "filename": "original-filename.pdf",
  "upload_timestamp": "2026-02-05T10:30:00Z",
  "file_size_bytes": 1048576,
  "content_type": "application/pdf",
  "chunk_count": 15,
  "embedding_model": "amazon.titan-embed-text-v2:0",
  "vector_dimension": 1024
}
```

**S3 Configuration**:
- Versioning: Disabled (cost optimization)
- Encryption: SSE-S3 (AES-256)
- Storage Class: S3 Standard
- Lifecycle Policy: Not implemented (manual cleanup)
- Access: Private (IAM-only access)

### 4. Amazon Bedrock

**Purpose**: LLM and embedding model inference

**Models Used**:

#### Embeddings Model
- **Model**: `amazon.titan-embed-text-v2:0`
- **Dimensions**: 1024
- **Input Limit**: 8,192 tokens
- **Use Case**: Convert text chunks and queries to vectors
- **Pricing**: $0.0001 per 1K tokens

#### LLM Model
- **Model**: `anthropic.claude-3-5-sonnet-20250110-v1:0`
- **Context Window**: 200K tokens
- **Use Case**: Agent reasoning and response generation
- **Pricing**: Input $3/MTok, Output $15/MTok

**Configuration**:
- Region: us-east-1 (for model availability)
- Throughput: On-demand (no provisioning)
- Guardrails: Not implemented (demo environment)

### 5. S3 Vectors

**Purpose**: High-performance vector similarity search

**Technology**: Amazon S3 Tables with vector search capabilities

**Configuration**:
```hcl
Vector Store Configuration:
- Index Type: Approximate k-NN (HNSW)
- Distance Metric: Cosine Similarity
- Dimensions: 1024 (matches Titan embeddings)
- M Parameter: 16 (HNSW graph connections)
- EF Construction: 200 (build quality)
```

**Vector Record Schema**:
```json
{
  "vector_id": "uuid-v4",
  "document_id": "uuid-v4",
  "chunk_index": 0,
  "embedding": [0.123, -0.456, ...],  # 1024 dimensions
  "chunk_text": "Original text content...",
  "metadata": {
    "document_filename": "example.pdf",
    "chunk_start_char": 0,
    "chunk_end_char": 1000
  }
}
```

**Search Parameters**:
- Top-K: 5 (configurable)
- Score Threshold: 0.7 (minimum similarity)
- Max Results: 10

### 6. CloudWatch Logs

**Purpose**: Centralized logging and observability

**Log Groups**:
```
/aws/agentcore/{agent-name}          # Agent execution logs
/aws/lambda/{function-name}          # If using Lambda components
/aws/ecs/{cluster}/{service}         # Streamlit UI logs (production)
```

**Metrics**:
- Agent invocation count
- Average response time
- Bedrock API call latency
- S3 Vectors search latency
- Error rates and exceptions

**Retention**: 7 days (dev), 30 days (prod)

## Data Flow

### Document Upload Flow

```
1. User uploads file via Streamlit UI
   ↓
2. UI sends file + chat message to AgentCore Agent
   ↓
3. Agent invokes S3 Document Manager Tool
   ↓
4. Tool generates unique document ID (UUID)
   ↓
5. Tool uploads file to S3: s3://{bucket}/documents/{doc-id}/original.{ext}
   ↓
6. Tool extracts text content (format-specific parsers)
   ↓
7. Tool chunks text using recursive character splitter:
   - Chunk size: 1000-1500 tokens (~4000-6000 chars)
   - Overlap: 200-300 tokens (~800-1200 chars)
   - Preserves sentence boundaries
   ↓
8. For each chunk:
   a. Agent invokes Bedrock Embeddings Client Tool
   b. Tool calls Bedrock Titan Embeddings API
   c. Receives 1024-dimension vector
   d. Agent invokes S3 Vectors Search Client Tool
   e. Tool stores vector with metadata in S3 Vectors
   ↓
9. Tool stores metadata in S3: s3://{bucket}/documents/{doc-id}/metadata.json
   ↓
10. Agent responds to user: "Document uploaded successfully!"
```

**Processing Time**: ~2-5 seconds per document (depending on size)

### Query Flow

```
1. User asks question via Streamlit UI
   ↓
2. UI sends question to AgentCore Agent
   ↓
3. Agent invokes Bedrock Embeddings Client Tool with query
   ↓
4. Tool generates query embedding vector (1024-dim)
   ↓
5. Agent invokes S3 Vectors Search Client Tool
   ↓
6. Tool performs k-NN search (top-5 similar chunks)
   ↓
7. Tool returns chunks with similarity scores and metadata
   ↓
8. Agent constructs prompt:
   - System prompt
   - Retrieved context chunks
   - User question
   ↓
9. Agent invokes Bedrock Claude model
   ↓
10. Model generates response using context
   ↓
11. Agent formats response with source attribution
   ↓
12. Response streamed back to UI
```

**Response Time**: ~1-3 seconds (including all API calls)

## Design Decisions

### 1. Why S3 Vectors over OpenSearch Serverless?

**Decision**: Use S3 Vectors (S3 Tables with vector search)

**Rationale**:
- **Cost**: Pay-per-query vs. always-on OpenSearch OCUs
- **Simplicity**: No cluster management, single S3-based service
- **Demo-Friendly**: Lower baseline costs for intermittent use
- **Future-Proof**: Newer AWS service aligned with S3 ecosystem

**Trade-offs**:
- Less mature than OpenSearch
- Fewer advanced search features (filters, aggregations)
- Best for straightforward k-NN search use cases

### 2. Why Strands Agents over LangChain/LlamaIndex?

**Decision**: Use Strands Agent Framework

**Rationale**:
- **AWS Native**: Built specifically for AgentCore Runtime
- **Simplified Deployment**: Direct integration with AWS services
- **Observability**: Built-in CloudWatch integration
- **Type Safety**: Better TypeScript/Python type hints

**Trade-offs**:
- Smaller community compared to LangChain
- Fewer pre-built integrations
- Requires AWS ecosystem commitment

### 3. Chunking Strategy: Recursive Character Splitting

**Decision**: Recursive character text splitter with overlap

**Parameters**:
- Chunk size: 1000-1500 tokens (~4000-6000 chars)
- Overlap: 200-300 tokens (~800-1200 chars)

**Rationale**:
- **Context Preservation**: Overlap prevents information loss at boundaries
- **Model Limits**: Stays within Bedrock embedding limits (8,192 tokens)
- **Retrieval Quality**: Balanced chunk size for semantic coherence
- **Format Agnostic**: Works across PDF, DOCX, TXT, MD

**Alternatives Considered**:
- Semantic chunking: More accurate but computationally expensive
- Sentence-based: Too granular, loses context
- Fixed-size: Doesn't respect sentence boundaries

### 4. Embedding Model: Amazon Titan v2

**Decision**: Use `amazon.titan-embed-text-v2:0`

**Rationale**:
- **AWS Native**: No external dependencies
- **Cost**: Most affordable option ($0.0001/1K tokens)
- **Performance**: 1024 dimensions, good retrieval quality
- **Availability**: Available in all Bedrock regions

**Alternatives Considered**:
- Cohere Embed: Higher cost, marginal quality improvement
- OpenAI Ada-002: External dependency, compliance concerns

### 5. LLM Model: Claude 3.5 Sonnet

**Decision**: Use Claude 3.5 Sonnet via Bedrock

**Rationale**:
- **Context Window**: 200K tokens (handles large documents)
- **Quality**: Strong reasoning for RAG applications
- **Speed**: Good balance of quality and latency
- **Cost**: $3/MTok input, $15/MTok output (reasonable)

**Alternatives Considered**:
- Claude 3 Opus: Higher quality but 4x cost
- Claude 3 Haiku: Faster but lower quality for complex RAG

### 6. Infrastructure: Terraform over CloudFormation

**Decision**: Use Terraform for IaC

**Rationale**:
- **Multi-Cloud**: Not locked to AWS-only
- **Ecosystem**: Rich module ecosystem
- **State Management**: Better state management with S3 backend
- **Developer Experience**: HCL is more readable than JSON/YAML

**Trade-offs**:
- Requires separate state backend setup
- Not natively integrated with AWS like CDK

### 7. CI/CD: GitHub Actions over CodePipeline

**Decision**: Use GitHub Actions for deployment

**Rationale**:
- **Source Integration**: Native GitHub integration
- **Cost**: Free for public repos, generous free tier
- **Flexibility**: Rich ecosystem of actions
- **Developer Experience**: YAML-based, widely adopted

**Trade-offs**:
- Requires GitHub as source control
- Less AWS-native than CodePipeline

## Security Architecture

### IAM Role Design

**Principle**: Least privilege access for all components

#### Agent IAM Role
```hcl
Permissions:
- s3:PutObject, s3:GetObject, s3:DeleteObject (documents bucket)
- bedrock:InvokeModel (Titan Embeddings, Claude)
- s3tables:GetTableObject, s3tables:PutTableObject (S3 Vectors)
- logs:CreateLogStream, logs:PutLogEvents (CloudWatch)

Deny:
- s3:DeleteBucket
- bedrock:* (except InvokeModel)
- iam:*
```

#### Terraform IAM Role
```hcl
Permissions:
- Full access to create/manage resources in scope
- s3:* on state bucket
- dynamodb:* on state lock table
- sts:AssumeRole for cross-account (if needed)
```

### Encryption

- **S3**: SSE-S3 (AES-256) enabled by default
- **S3 Vectors**: Encryption at rest (managed by AWS)
- **CloudWatch Logs**: Encrypted by default
- **Bedrock**: Encryption in transit (TLS 1.2+)

### Network Security

**Development**:
- Public internet access (demo environment)
- No VPC required

**Production Considerations**:
- Deploy AgentCore in VPC
- Private subnets for agent runtime
- VPC endpoints for S3, Bedrock
- NAT Gateway for external API access

### Data Protection

- **Input Validation**: Sanitize all file uploads
- **File Type Restrictions**: Whitelist allowed MIME types
- **Size Limits**: Max 10MB per document
- **Rate Limiting**: Prevent abuse (future enhancement)

## Scalability & Performance

### Horizontal Scaling

**AgentCore Runtime**:
- Auto-scales based on request volume
- No configuration required
- Cold start: ~2-3 seconds (first request)
- Warm execution: <500ms overhead

**S3 & S3 Vectors**:
- Automatically scales to handle any request volume
- No capacity planning required
- 99.99% availability SLA

### Performance Optimization

**Caching Strategy** (Future Enhancement):
```
- Cache embeddings for frequently asked questions
- Use ElastiCache Redis for query result caching
- TTL: 1 hour for query results
```

**Batch Processing** (Future Enhancement):
```
- Process multiple documents in parallel
- Use SQS queue + Lambda for async processing
- Reduces user wait time for uploads
```

### Bottlenecks & Mitigations

| Component | Potential Bottleneck | Mitigation |
|-----------|---------------------|------------|
| Bedrock Embeddings | Rate limits (thousands/sec) | Implement exponential backoff |
| S3 Vectors | Search latency for large datasets | Use metadata filtering, smaller index |
| Agent Runtime | Cold starts | Keep agent warm with CloudWatch Events |
| File Upload | Large files timeout | Implement S3 presigned URLs |

## Cost Optimization

### Cost Breakdown (Monthly Estimates)

**Development Environment** (~10 documents, 50 queries/month):
```
S3 Storage (10GB):                 $0.23
S3 Vectors (50 queries):           $2.50
Bedrock Embeddings (100K tokens):  $0.10
Bedrock LLM (500K tokens):         $7.50
AgentCore (50 invocations):        $2.50
CloudWatch Logs (1GB):             $0.50
─────────────────────────────────────────
Total:                            ~$13.33/month
```

**Production Environment** (~1000 documents, 10K queries/month):
```
S3 Storage (1TB):                 $23.00
S3 Vectors (10K queries):        $500.00
Bedrock Embeddings (20M tokens):  $20.00
Bedrock LLM (100M tokens):     $1,500.00
AgentCore (10K invocations):     $500.00
CloudWatch Logs (50GB):           $25.00
─────────────────────────────────────────
Total:                         ~$2,568/month
```

### Cost Optimization Strategies

1. **S3 Lifecycle Policies**: Move old documents to Glacier
2. **Embedding Caching**: Cache embeddings for duplicate content
3. **Smaller Chunks**: Reduce embedding API calls (trade-off: quality)
4. **Response Caching**: Cache answers for common questions
5. **Model Selection**: Use Haiku for simple queries, Sonnet for complex
6. **Batch Processing**: Reduce AgentCore invocations with queuing

### Cost Monitoring

**Budgets**:
- Dev: $50/month alert threshold
- Prod: $5,000/month alert threshold

**Cost Allocation Tags**:
```hcl
Tags:
  Project: "agentic-rag-demo"
  Environment: "dev|prod"
  ManagedBy: "terraform"
  CostCenter: "demo"
```

## Future Enhancements

1. **Authentication**: Cognito User Pools for multi-user support
2. **Document Updates**: Version control and re-embedding pipeline
3. **Multi-Modal**: Support for images, audio transcription
4. **Advanced Search**: Metadata filtering, date ranges, document types
5. **Analytics Dashboard**: Query analytics, popular documents, usage trends
6. **Feedback Loop**: User ratings to improve retrieval quality
7. **Multi-Language**: Support for non-English documents

---

**Document Version**: 1.0
**Last Updated**: 2026-02-05
**Maintained By**: Development Team
