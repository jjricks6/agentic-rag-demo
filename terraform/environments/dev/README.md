# Development Environment

Terraform configuration for the development environment of Recall.

## Overview

This environment is optimized for:
- Fast iteration and testing
- Cost savings (versioning disabled, relaxed monitoring)
- Easy cleanup (force_destroy enabled)
- Local development support (CORS for localhost)

## Prerequisites

Before deploying:

1. ✅ **Backend created**: Run `terraform apply` in `../../backend/`
2. ✅ **AWS credentials configured**: `aws configure`
3. ✅ **Bedrock models enabled**: Titan Embeddings v2, Claude 3.5 Sonnet
4. ✅ **Terraform >= 1.5.0** installed

## Quick Start

### 1. Copy Configuration

```bash
cd terraform/environments/dev
cp terraform.tfvars.example terraform.tfvars

# Edit terraform.tfvars with your values
# Most defaults should work fine for dev
```

### 2. Create Placeholder Lambda

```bash
# Create a minimal placeholder for initial deployment
echo 'def handler(event, context): return {"statusCode": 200}' > lambda_placeholder.py
zip lambda-placeholder.zip lambda_placeholder.py
rm lambda_placeholder.py
```

### 3. Initialize Terraform

```bash
# Option 1: Auto-generate backend config (Recommended)
cd ../../scripts
./generate-backend-configs.sh
cd ../environments/dev

# Initialize with backend config file
terraform init -backend-config=backend.hcl

# Option 2: Manual backend config
# If you prefer to configure manually, see terraform/scripts/README.md
```

### 4. Plan and Deploy

```bash
# Review the plan
terraform plan

# Deploy infrastructure
terraform apply

# Save outputs for UI configuration
terraform output -json > ../../../agent-config-dev.json
```

## What Gets Deployed

| Resource | Purpose | Cost/Month |
|----------|---------|------------|
| S3 Bucket (documents) | Document storage | ~$0.50 |
| S3 Vector Bucket | Vector embeddings | ~$1.00 |
| Vector Index (HNSW) | Similarity search | Pay per query |
| Bedrock Agent | Agent orchestration | Free |
| 2x Lambda Functions | Action group handlers | ~$0.50 |
| CloudWatch Logs | Monitoring | ~$1.00 |
| CloudWatch Dashboard | Visualization | Free |
| IAM Roles/Policies | Security | Free |
| **Total** | | **~$3.00/month** |

Plus usage costs:
- Bedrock LLM: ~$0.003/request
- Bedrock Embeddings: ~$0.0001/document
- Vector searches: ~$0.001/query

## Configuration Options

### Use Claude Haiku (Faster, Cheaper)

```hcl
llm_model_id = "anthropic.claude-3-haiku-20240307"
```

### Disable CloudWatch Alarms

```hcl
enable_cloudwatch_alarms = false
```

### Adjust Log Retention

```hcl
log_retention_days = 3  # Minimal retention for cost savings
```

## Development Workflow

### 1. Initial Deployment

```bash
terraform init
terraform plan
terraform apply
```

### 2. Update Lambda Functions

After building your Lambda functions:

```bash
# Deploy updated Lambda code
terraform apply \
  -target=aws_lambda_function.document_handler \
  -target=aws_lambda_function.search_handler
```

### 3. Test Agent

```bash
# Test via AWS CLI
aws bedrock-agent-runtime invoke-agent \
  --agent-id $(terraform output -raw agent_id) \
  --agent-alias-id $(terraform output -raw agent_alias_id) \
  --session-id test-$(date +%s) \
  --input-text "Hello, please list available documents." \
  --region us-east-1 \
  response.json

# View response
cat response.json
```

### 4. Monitor Logs

```bash
# Tail agent logs
aws logs tail $(terraform output -raw log_group_name) --follow

# Query with CloudWatch Insights
aws logs start-query \
  --log-group-name $(terraform output -raw log_group_name) \
  --start-time $(date -u -d '1 hour ago' +%s) \
  --end-time $(date -u +%s) \
  --query-string 'fields @timestamp, @message | sort @timestamp desc | limit 20'
```

### 5. Iterate on Agent Code

```bash
# Make changes to agent/lambda code
cd ../../../agent/lambda
# ... edit code ...

# Rebuild
./build.sh

# Update Lambda
cd ../../terraform/environments/dev
terraform apply -target=aws_lambda_function.document_handler
```

## Cleanup

To destroy the dev environment:

```bash
# Remove all infrastructure
terraform destroy

# Confirm by typing 'yes'
```

**Note**: `force_destroy = true` is set on S3 buckets, so they will be deleted even if they contain objects.

## Troubleshooting

### Issue: Lambda placeholder not found

**Error**: `Error: error creating Lambda Function: InvalidParameterValueException`

**Solution**:
```bash
# Create placeholder
echo 'def handler(event, context): return {"statusCode": 200}' > lambda_placeholder.py
zip lambda-placeholder.zip lambda_placeholder.py
terraform apply
```

### Issue: Bedrock model not accessible

**Error**: `ModelNotAccessibleException`

**Solution**:
1. Go to [Bedrock Console](https://console.aws.amazon.com/bedrock)
2. Enable model access for Titan Embeddings v2 and Claude 3.5 Sonnet
3. Wait for approval
4. Retry: `terraform apply`

### Issue: Backend not initialized

**Error**: `Backend initialization required` or `backend.hcl not found`

**Solution**:
```bash
# Deploy backend first
cd ../../backend
terraform init && terraform apply

# Generate backend configs
cd ../scripts
./generate-backend-configs.sh

# Then retry dev
cd ../environments/dev
terraform init -backend-config=backend.hcl
```

## Best Practices for Dev

1. ✅ **Commit often**: Use git to track infrastructure changes
2. ✅ **Test locally**: Run Streamlit UI locally before deploying
3. ✅ **Monitor costs**: Check AWS Cost Explorer weekly
4. ✅ **Use terraform plan**: Always review before applying
5. ✅ **Keep it simple**: Don't over-optimize in dev

## Next Steps

After successful deployment:

1. **Build Lambda functions**: See `agent/lambda/README.md`
2. **Run Streamlit UI**: See `ui/streamlit-app/README.md`
3. **Test end-to-end**: Upload document → Ask question → Verify response
4. **Review logs**: Check CloudWatch for any errors
5. **Iterate**: Make changes and redeploy

## Additional Resources

- [../../docs/SETUP.md](../../docs/SETUP.md) - Complete setup guide
- [../../docs/ARCHITECTURE.md](../../docs/ARCHITECTURE.md) - Architecture details
- [../../modules/](../../modules/) - Module documentation

---

**Environment**: Development
**Last Updated**: 2026-02-05
**Terraform Version**: >= 1.5.0
