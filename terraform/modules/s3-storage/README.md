# S3 Storage Module

Terraform module for creating and configuring S3 buckets for document storage in Recall.

## Features

- ✅ **Secure by Default**: Public access blocked, HTTPS-only, encryption enabled
- ✅ **Cost Optimized**: Lifecycle rules, Glacier transitions, multipart upload cleanup
- ✅ **Flexible**: Supports versioning, CORS, notifications, and custom encryption
- ✅ **Monitored**: Optional CloudWatch alarms for bucket size
- ✅ **Tagged**: Automatic tagging for cost allocation and management

## Usage

### Basic Usage

```hcl
module "documents_bucket" {
  source = "../../modules/s3-storage"

  project_name     = "agentic-rag-demo"
  environment      = "dev"
  bucket_suffix    = "documents"
  agent_role_arns  = [aws_iam_role.agent.arn]

  tags = {
    Project = "agentic-rag-demo"
    Team    = "AI/ML"
  }
}
```

### With Versioning and Lifecycle Rules

```hcl
module "documents_bucket" {
  source = "../../modules/s3-storage"

  project_name                        = "agentic-rag-demo"
  environment                         = "prod"
  bucket_suffix                       = "documents"
  agent_role_arns                     = [aws_iam_role.agent.arn]

  # Enable versioning
  enable_versioning                   = true
  noncurrent_version_retention_days   = 90

  # Enable lifecycle rules
  enable_lifecycle_rules              = true
  enable_glacier_transition           = true
  glacier_transition_days             = 180
  glacier_transition_prefix           = "archive/"

  tags = {
    Project     = "agentic-rag-demo"
    Environment = "prod"
  }
}
```

### With CORS for Web Uploads

```hcl
module "documents_bucket" {
  source = "../../modules/s3-storage"

  project_name     = "agentic-rag-demo"
  environment      = "dev"
  bucket_suffix    = "documents"
  agent_role_arns  = [aws_iam_role.agent.arn]

  # Enable CORS for Streamlit uploads
  enable_cors             = true
  cors_allowed_origins    = ["http://localhost:8501", "https://app.example.com"]
  cors_allowed_methods    = ["GET", "PUT", "POST"]
  cors_allowed_headers    = ["*"]

  tags = {
    Project = "agentic-rag-demo"
  }
}
```

### With KMS Encryption and Monitoring

```hcl
module "documents_bucket" {
  source = "../../modules/s3-storage"

  project_name     = "agentic-rag-demo"
  environment      = "prod"
  bucket_suffix    = "documents"
  agent_role_arns  = [aws_iam_role.agent.arn]

  # KMS encryption
  kms_key_id       = aws_kms_key.s3.id

  # Monitoring
  enable_size_alarm           = true
  size_alarm_threshold_bytes  = 107374182400  # 100 GB
  alarm_sns_topic_arns        = [aws_sns_topic.alerts.arn]

  tags = {
    Project     = "agentic-rag-demo"
    Environment = "prod"
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
| agent_role_arns | IAM roles with bucket access | `list(string)` | `[]` |

### Optional Inputs

| Name | Description | Type | Default |
|------|-------------|------|---------|
| bucket_suffix | Suffix for bucket name | `string` | `"documents"` |
| enable_versioning | Enable bucket versioning | `bool` | `false` |
| enable_lifecycle_rules | Enable lifecycle policies | `bool` | `true` |
| enable_cors | Enable CORS configuration | `bool` | `false` |
| kms_key_id | KMS key for encryption | `string` | `null` |
| force_destroy | Allow bucket destruction with objects | `bool` | `false` |
| tags | Additional resource tags | `map(string)` | `{}` |

See [variables.tf](./variables.tf) for complete list.

## Outputs

| Name | Description |
|------|-------------|
| bucket_id | The S3 bucket name |
| bucket_arn | The S3 bucket ARN |
| bucket_domain_name | The bucket domain name |
| bucket_region | The AWS region |
| versioning_enabled | Whether versioning is enabled |
| encryption_algorithm | Encryption algorithm used |

See [outputs.tf](./outputs.tf) for complete list.

## Security Features

### Encryption
- **Default**: AES-256 server-side encryption
- **Optional**: Customer-managed KMS keys
- **In Transit**: HTTPS-only via bucket policy

### Access Control
- Public access completely blocked
- IAM-based access only
- Bucket policy enforces secure transport
- Agent roles explicitly granted permissions

### Auditing
- CloudTrail integration (account level)
- Optional S3 access logging
- CloudWatch metrics available

## Cost Optimization

### Lifecycle Policies
1. **Old Version Cleanup**: Deletes noncurrent versions after retention period
2. **Glacier Transition**: Moves archived objects to low-cost storage
3. **Multipart Upload Cleanup**: Removes incomplete uploads after 7 days

### Cost Breakdown (Estimate)

**Development** (10 GB, minimal versioning):
- Storage: ~$0.23/month
- Requests (1000/month): ~$0.01/month
- **Total: ~$0.24/month**

**Production** (1 TB, with versioning):
- Storage: ~$23/month
- Versioning overhead (20%): ~$5/month
- Requests (10K/month): ~$0.05/month
- **Total: ~$28/month**

With Glacier transition (50% of data):
- Storage: ~$11.50/month (S3) + $2/month (Glacier)
- **Total: ~$18.50/month** (36% savings)

## Examples

### Full Production Configuration

```hcl
module "prod_documents" {
  source = "../../modules/s3-storage"

  # Required
  project_name    = "agentic-rag-demo"
  environment     = "prod"
  bucket_suffix   = "documents"
  agent_role_arns = [
    aws_iam_role.agent.arn,
    aws_iam_role.admin.arn
  ]

  # Versioning
  enable_versioning                 = true
  noncurrent_version_retention_days = 90

  # Lifecycle
  enable_lifecycle_rules    = true
  enable_glacier_transition = true
  glacier_transition_days   = 180
  glacier_transition_prefix = "archive/"

  # Security
  kms_key_id = aws_kms_key.s3.id

  # Monitoring
  enable_size_alarm          = true
  size_alarm_threshold_bytes = 1099511627776  # 1 TB
  alarm_sns_topic_arns       = [aws_sns_topic.prod_alerts.arn]

  # CORS (if using web uploads)
  enable_cors          = true
  cors_allowed_origins = ["https://app.example.com"]
  cors_allowed_methods = ["GET", "PUT", "POST"]

  # Tags
  tags = {
    Project     = "agentic-rag-demo"
    Environment = "prod"
    ManagedBy   = "terraform"
    CostCenter  = "AI-Research"
    Compliance  = "GDPR"
  }
}
```

### Development Configuration

```hcl
module "dev_documents" {
  source = "../../modules/s3-storage"

  project_name    = "agentic-rag-demo"
  environment     = "dev"
  bucket_suffix   = "documents"
  agent_role_arns = [aws_iam_role.agent_dev.arn]

  # Simplified for dev
  enable_versioning      = false
  enable_lifecycle_rules = true
  enable_cors            = true
  force_destroy          = true  # Allow easy cleanup in dev

  tags = {
    Project     = "agentic-rag-demo"
    Environment = "dev"
  }
}
```

## Troubleshooting

### Issue: Bucket name already exists

S3 bucket names must be globally unique. The module automatically appends the AWS account ID to prevent conflicts, but if you still encounter this error:

1. Check for existing buckets: `aws s3 ls | grep agentic-rag-demo`
2. Change the `bucket_suffix` variable to something unique

### Issue: Access Denied errors

Ensure the IAM roles listed in `agent_role_arns` are correctly specified and have been created before this module runs.

### Issue: CORS errors in browser

Verify:
1. `enable_cors = true`
2. Your origin is in `cors_allowed_origins`
3. Methods match your application needs
4. Browser cache is cleared

## Additional Resources

- [AWS S3 Best Practices](https://docs.aws.amazon.com/AmazonS3/latest/userguide/security-best-practices.html)
- [S3 Lifecycle Configuration](https://docs.aws.amazon.com/AmazonS3/latest/userguide/object-lifecycle-mgmt.html)
- [S3 CORS Configuration](https://docs.aws.amazon.com/AmazonS3/latest/userguide/cors.html)

## License

MIT - See main repository LICENSE file

---

**Module Version**: 1.0.0
**Last Updated**: 2026-02-05
