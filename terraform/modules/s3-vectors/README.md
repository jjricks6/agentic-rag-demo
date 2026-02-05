# S3 Vectors Module

Terraform module for creating and configuring S3-based vector storage using S3 Tables with vector search capabilities.

## Overview

This module provisions storage for vector embeddings used in the RAG (Retrieval Augmented Generation) system. It uses Amazon S3 Tables, which provides native vector similarity search capabilities with HNSW (Hierarchical Navigable Small World) indexing.

> **Note**: S3 Tables with vector search is a newer AWS service (announced 2024-2025). Terraform provider support is evolving. This module provides the foundation and can be extended as AWS provider capabilities mature.

## Features

- ✅ **Vector Similarity Search**: Built-in HNSW indexing for fast k-NN queries
- ✅ **Scalable**: Serverless architecture scales automatically
- ✅ **Secure**: Encryption at rest, IAM-based access control
- ✅ **Cost-Effective**: Pay only for storage and queries used
- ✅ **Flexible Indexing**: Configurable HNSW parameters for speed/accuracy trade-offs
- ✅ **Monitored**: CloudWatch alarms for storage size and query latency

## Usage

### Basic Usage

```hcl
module "vector_storage" {
  source = "../../modules/s3-vectors"

  project_name     = "agentic-rag-demo"
  environment      = "dev"
  agent_role_arns  = [aws_iam_role.agent.arn]

  # Vector configuration (must match embedding model)
  vector_dimensions = 1024  # Amazon Titan Embeddings v2
  distance_metric   = "cosine"

  tags = {
    Project = "agentic-rag-demo"
    Team    = "AI/ML"
  }
}
```

### Production Configuration with Monitoring

```hcl
module "vector_storage" {
  source = "../../modules/s3-vectors"

  project_name     = "agentic-rag-demo"
  environment      = "prod"
  agent_role_arns  = [aws_iam_role.agent.arn]

  # Vector configuration
  vector_dimensions = 1024
  distance_metric   = "cosine"
  index_type        = "hnsw"

  # HNSW tuning for production
  hnsw_m              = 32      # More connections = better recall
  hnsw_ef_construction = 400    # Higher quality index
  hnsw_ef_search      = 200     # Better search accuracy

  # Monitoring
  enable_size_alarm           = true
  size_alarm_threshold_bytes  = 214748364800  # 200 GB
  enable_latency_alarm        = true
  latency_alarm_threshold_ms  = 500
  alarm_sns_topic_arns        = [aws_sns_topic.alerts.arn]

  # Encryption
  kms_key_id = aws_kms_key.vectors.id

  tags = {
    Project     = "agentic-rag-demo"
    Environment = "prod"
    Criticality = "high"
  }
}
```

### With Custom Metadata Schema

```hcl
module "vector_storage" {
  source = "../../modules/s3-vectors"

  project_name     = "agentic-rag-demo"
  environment      = "dev"
  agent_role_arns  = [aws_iam_role.agent.arn]

  vector_dimensions = 1024
  distance_metric   = "cosine"

  # Custom metadata fields
  metadata_fields = [
    {
      name = "document_id"
      type = "string"
    },
    {
      name = "chunk_index"
      type = "integer"
    },
    {
      name = "chunk_text"
      type = "string"
    },
    {
      name = "document_type"
      type = "string"
    },
    {
      name = "author"
      type = "string"
    },
    {
      name = "created_at"
      type = "timestamp"
    },
    {
      name = "confidence_score"
      type = "float"
    }
  ]

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
| agent_role_arns | IAM roles with access | `list(string)` | `[]` |

### Vector Configuration

| Name | Description | Type | Default |
|------|-------------|------|---------|
| vector_dimensions | Embedding dimensions | `number` | `1024` |
| distance_metric | Similarity metric | `string` | `"cosine"` |
| index_type | Index type (hnsw/flat) | `string` | `"hnsw"` |
| table_name | S3 Tables table name | `string` | `"embeddings"` |

### HNSW Parameters

| Name | Description | Type | Default |
|------|-------------|------|---------|
| hnsw_m | Connections per layer | `number` | `16` |
| hnsw_ef_construction | Index build quality | `number` | `200` |
| hnsw_ef_search | Search accuracy | `number` | `100` |

See [variables.tf](./variables.tf) for complete list.

## Outputs

| Name | Description |
|------|-------------|
| bucket_id | S3 bucket name |
| bucket_arn | S3 bucket ARN |
| vector_dimensions | Embedding dimensions |
| distance_metric | Similarity metric |
| hnsw_config | HNSW parameters |
| vector_store_config | Complete connection config |

See [outputs.tf](./outputs.tf) for complete list.

## Vector Configuration Guide

### Choosing Vector Dimensions

Match your embedding model:

| Model | Dimensions |
|-------|-----------|
| Amazon Titan Embeddings v1 | 1536 |
| Amazon Titan Embeddings v2 | 1024 or 256 |
| Cohere Embed v3 | 1024 |
| OpenAI Ada 002 | 1536 |

### Choosing Distance Metric

| Metric | Use Case | Formula |
|--------|----------|---------|
| **cosine** | Text embeddings (recommended) | 1 - (A·B)/(‖A‖‖B‖) |
| **euclidean** | Spatial data, images | √Σ(Ai-Bi)² |
| **dot_product** | When vectors are normalized | -(A·B) |

**Recommendation**: Use `cosine` for text-based RAG systems.

### HNSW Index Tuning

Trade-off between speed, accuracy, and build time:

#### Development (Fast, Lower Quality)
```hcl
hnsw_m              = 16
hnsw_ef_construction = 200
hnsw_ef_search      = 100
```

#### Production (Balanced)
```hcl
hnsw_m              = 32
hnsw_ef_construction = 400
hnsw_ef_search      = 200
```

#### High Accuracy (Slower)
```hcl
hnsw_m              = 48
hnsw_ef_construction = 512
hnsw_ef_search      = 400
```

**Parameters Explained**:
- **M**: Number of bi-directional links (4-64). Higher = better recall, more memory
- **ef_construction**: Controls index build quality (100-512). Higher = better index, slower builds
- **ef_search**: Controls search accuracy (10-512). Higher = better recall, slower queries

## Performance Characteristics

### Query Latency

Typical p99 latencies for 1M vectors:

| Configuration | Latency (ms) |
|--------------|-------------|
| Dev (M=16, ef=100) | 50-100 |
| Prod (M=32, ef=200) | 100-200 |
| High Accuracy (M=48, ef=400) | 200-400 |

### Recall vs Speed

| ef_search | Recall @10 | Latency |
|-----------|-----------|---------|
| 50 | ~85% | Fast |
| 100 | ~92% | Medium |
| 200 | ~96% | Slower |
| 400 | ~98% | Slow |

## Cost Estimation

### Storage Costs

**Per 1M vectors (1024 dimensions each)**:
- Storage: ~5 GB
- S3 Standard: ~$0.115/GB/month
- **Total: ~$0.58/month**

### Query Costs

**Approximate pricing** (pay-per-query):
- Search query (k=5): ~$0.001
- 10,000 queries/month: ~$10
- 100,000 queries/month: ~$100

### Full Cost Example

**Development** (100K vectors, 1K queries/month):
- Storage: ~$0.06/month
- Queries: ~$1/month
- **Total: ~$1.06/month**

**Production** (10M vectors, 100K queries/month):
- Storage: ~$5.75/month
- Queries: ~$100/month
- **Total: ~$105.75/month**

## S3 Tables Setup

As S3 Tables is a newer service, you may need to complete setup using AWS CLI alongside Terraform:

### Create Table Bucket (if not supported in Terraform)

```bash
# Set variables
NAMESPACE="agentic-rag-demo-dev"
REGION="us-east-1"

# Create table bucket
aws s3tables create-table-bucket \
  --name ${NAMESPACE} \
  --region ${REGION}

# Create table with vector index
aws s3tables create-table \
  --table-bucket-arn arn:aws:s3tables:${REGION}:ACCOUNT_ID:bucket/${NAMESPACE} \
  --namespace default \
  --name embeddings \
  --format ICEBERG \
  --schema file://vector-schema.json
```

### Vector Schema Example

**vector-schema.json**:
```json
{
  "type": "struct",
  "fields": [
    {
      "name": "vector_id",
      "type": "string",
      "nullable": false
    },
    {
      "name": "embedding",
      "type": "array<float>",
      "nullable": false,
      "metadata": {
        "vector_index": {
          "dimensions": 1024,
          "distance_metric": "cosine",
          "index_type": "hnsw",
          "hnsw_m": 32,
          "hnsw_ef_construction": 400
        }
      }
    },
    {
      "name": "document_id",
      "type": "string",
      "nullable": false
    },
    {
      "name": "chunk_text",
      "type": "string",
      "nullable": true
    }
  ]
}
```

## Agent Integration

Use the `vector_store_config` output to configure your agent:

```python
# In your Strands agent
import boto3

vector_config = {
    "bucket_name": "agentic-rag-demo-vectors-dev-123456789012",
    "region": "us-east-1",
    "table_name": "embeddings",
    "vector_dimensions": 1024,
    "distance_metric": "cosine",
    "top_k": 5
}

# Example: Search vectors
def search_vectors(query_embedding, top_k=5):
    s3_client = boto3.client('s3', region_name=vector_config['region'])

    # S3 Tables vector search API (example)
    response = s3_client.search_vectors(
        Bucket=vector_config['bucket_name'],
        Table=vector_config['table_name'],
        QueryVector=query_embedding,
        TopK=top_k,
        DistanceMetric=vector_config['distance_metric']
    )

    return response['Results']
```

## Troubleshooting

### Issue: S3 Tables not available in region

S3 Tables is available in select regions. Check availability:

```bash
aws s3tables list-table-buckets --region us-east-1
```

If not available, consider:
1. Using a supported region (us-east-1, us-west-2)
2. Alternative: OpenSearch Serverless or Aurora with pgvector

### Issue: Vector search returning poor results

1. **Check ef_search**: Increase for better recall
2. **Verify dimensions**: Must match embedding model exactly
3. **Distance metric**: Use cosine for text embeddings
4. **Normalize embeddings**: Some metrics require unit vectors

### Issue: High query latency

1. **Reduce ef_search**: Lower for faster queries
2. **Increase HNSW M**: Better graph connectivity
3. **Check data size**: Latency increases with dataset size
4. **Consider sharding**: Split large datasets

## Additional Resources

- [AWS S3 Tables Documentation](https://docs.aws.amazon.com/s3tables/)
- [HNSW Algorithm Paper](https://arxiv.org/abs/1603.09320)
- [Vector Search Best Practices](https://www.pinecone.io/learn/vector-database/)

## License

MIT - See main repository LICENSE file

---

**Module Version**: 1.0.0
**Last Updated**: 2026-02-05
**Note**: S3 Tables support evolving, may require AWS CLI for initial setup
