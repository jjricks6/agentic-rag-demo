# Terraform Backend Setup

This directory contains the Terraform configuration for setting up the remote state backend infrastructure.

## Overview

The backend consists of:
- **S3 Bucket**: Stores Terraform state files with versioning enabled
- **DynamoDB Table**: Provides state locking to prevent concurrent modifications
- **S3 Logs Bucket**: Stores access logs for the state bucket
- **KMS Key** (optional): Provides enhanced encryption for state files

## Features

✅ **State Versioning**: Automatic versioning for state recovery
✅ **State Locking**: DynamoDB-based locking prevents concurrent writes
✅ **Encryption**: Server-side encryption (AES-256) by default
✅ **Secure Access**: Enforces HTTPS and blocks public access
✅ **Access Logging**: Tracks all access to state bucket
✅ **Lifecycle Management**: Automatic cleanup of old versions and logs
✅ **Point-in-Time Recovery**: DynamoDB backup enabled

## Prerequisites

- AWS CLI configured with appropriate credentials
- Terraform >= 1.5.0 installed
- IAM permissions to create:
  - S3 buckets
  - DynamoDB tables
  - KMS keys (if using KMS encryption)

## Quick Start

### 1. Configure Variables (Optional)

Create a `terraform.tfvars` file to customize settings:

```hcl
aws_region                   = "us-east-1"
project_name                 = "agentic-rag-demo"
state_version_retention_days = 90
log_retention_days          = 30
enable_kms_encryption       = false

tags = {
  Team      = "DevOps"
  CostCenter = "Engineering"
}
```

### 2. Initialize and Deploy

```bash
# Navigate to backend directory
cd terraform/backend

# Initialize Terraform
terraform init

# Review the plan
terraform plan

# Apply the configuration
terraform apply

# Confirm by typing 'yes'
```

### 3. Save the Outputs

After successful deployment, save the outputs:

```bash
# View outputs
terraform output

# Save to file for reference
terraform output -json > backend-outputs.json
```

### 4. Configure Other Environments

Copy the backend configuration snippet for use in dev/prod environments:

```bash
# Display the backend config snippet
terraform output -raw backend_config_snippet
```

## Backend Configuration for Environments

After creating the backend, use this configuration in your environment-specific Terraform:

### For Development Environment

In `terraform/environments/dev/main.tf`:

```hcl
terraform {
  backend "s3" {
    bucket         = "agentic-rag-demo-tfstate-123456789012"  # From backend output
    key            = "dev/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "agentic-rag-demo-tfstate-lock"          # From backend output
    encrypt        = true
  }
}
```

### For Production Environment

In `terraform/environments/prod/main.tf`:

```hcl
terraform {
  backend "s3" {
    bucket         = "agentic-rag-demo-tfstate-123456789012"  # From backend output
    key            = "prod/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "agentic-rag-demo-tfstate-lock"          # From backend output
    encrypt        = true
  }
}
```

## Variables Reference

| Variable | Description | Default | Required |
|----------|-------------|---------|----------|
| `aws_region` | AWS region for backend resources | `us-east-1` | No |
| `project_name` | Project name for resource naming | `agentic-rag-demo` | No |
| `state_version_retention_days` | Days to keep old state versions | `90` | No |
| `log_retention_days` | Days to keep access logs | `30` | No |
| `enable_kms_encryption` | Enable KMS encryption | `false` | No |
| `tags` | Additional tags for resources | `{}` | No |

## Outputs Reference

| Output | Description |
|--------|-------------|
| `state_bucket_name` | Name of the S3 state bucket |
| `state_bucket_arn` | ARN of the S3 state bucket |
| `state_lock_table_name` | Name of the DynamoDB lock table |
| `state_lock_table_arn` | ARN of the DynamoDB lock table |
| `logs_bucket_name` | Name of the logs bucket |
| `backend_config` | Backend configuration object |
| `backend_config_snippet` | Copy-paste backend config |

## Security Features

### Encryption
- **At Rest**: AES-256 server-side encryption by default
- **In Transit**: HTTPS required (HTTP denied by bucket policy)
- **Optional KMS**: Enhanced encryption with customer-managed keys

### Access Control
- Public access completely blocked
- IAM-based access control only
- Bucket policy enforces secure transport

### Auditing
- All S3 access logged to separate bucket
- CloudTrail integration (if enabled in account)
- DynamoDB point-in-time recovery enabled

### State Protection
- Versioning enabled for recovery
- State locking prevents concurrent modifications
- 90-day retention of old versions by default

## Cost Estimation

**Monthly costs for backend infrastructure**:

```
S3 State Bucket:
- Storage (1GB):           ~$0.02
- Versioning overhead:     ~$0.05
- Requests (1000/month):   ~$0.01

S3 Logs Bucket:
- Storage (500MB):         ~$0.01
- Requests:                ~$0.01

DynamoDB Lock Table:
- On-demand (100 ops):     ~$0.13
- Backup storage:          ~$0.02

Total: ~$0.25/month
```

KMS encryption adds ~$1/month if enabled.

## Maintenance

### View State Bucket Contents

```bash
# List all state files
aws s3 ls s3://agentic-rag-demo-tfstate-123456789012/ --recursive

# Expected structure:
# dev/terraform.tfstate
# prod/terraform.tfstate
```

### Check State Lock Status

```bash
# View DynamoDB lock table
aws dynamodb scan \
  --table-name agentic-rag-demo-tfstate-lock \
  --output table
```

### Recover from State Version

```bash
# List versions
aws s3api list-object-versions \
  --bucket agentic-rag-demo-tfstate-123456789012 \
  --prefix dev/terraform.tfstate

# Restore specific version
aws s3api get-object \
  --bucket agentic-rag-demo-tfstate-123456789012 \
  --key dev/terraform.tfstate \
  --version-id <VERSION_ID> \
  terraform.tfstate.recovered
```

### Monitor Access Logs

```bash
# Download recent logs
aws s3 sync \
  s3://agentic-rag-demo-tfstate-logs-123456789012/state-access-logs/ \
  ./logs/ \
  --exclude "*" \
  --include "$(date +%Y-%m-%d)*"
```

## Troubleshooting

### Issue: Bucket Name Already Exists

**Error**:
```
Error: creating S3 Bucket: BucketAlreadyExists
```

**Solution**:
The bucket name must be globally unique. Update the `project_name` variable:

```hcl
project_name = "your-unique-project-name"
```

### Issue: Insufficient Permissions

**Error**:
```
Error: creating S3 Bucket: AccessDenied
```

**Solution**:
Ensure your IAM user/role has these permissions:
- `s3:CreateBucket`, `s3:PutBucketPolicy`, `s3:PutBucketVersioning`
- `dynamodb:CreateTable`, `dynamodb:UpdateTable`
- `kms:CreateKey`, `kms:CreateAlias` (if using KMS)

### Issue: State Lock Timeout

**Error**:
```
Error: Error acquiring the state lock
```

**Solution**:
A previous Terraform operation may have crashed without releasing the lock:

```bash
# Force unlock (use with caution!)
terraform force-unlock <LOCK_ID>
```

### Issue: Cannot Delete Backend

**Error**:
```
Error: deleting S3 Bucket: BucketNotEmpty
```

**Solution**:
Empty the buckets first:

```bash
# Empty state bucket
aws s3 rm s3://agentic-rag-demo-tfstate-123456789012/ --recursive

# Empty logs bucket
aws s3 rm s3://agentic-rag-demo-tfstate-logs-123456789012/ --recursive

# Then retry destroy
terraform destroy
```

## Disaster Recovery

### Backup Strategy

1. **Automatic S3 Versioning**: Keeps 90 days of state history
2. **DynamoDB Point-in-Time Recovery**: 35-day recovery window
3. **Cross-Region Replication** (optional): Add for critical workloads

### Recovery Procedure

If state is corrupted or lost:

1. List available versions:
   ```bash
   aws s3api list-object-versions \
     --bucket <BUCKET_NAME> \
     --prefix <ENV>/terraform.tfstate
   ```

2. Download previous version:
   ```bash
   aws s3api get-object \
     --bucket <BUCKET_NAME> \
     --key <ENV>/terraform.tfstate \
     --version-id <VERSION_ID> \
     terraform.tfstate.backup
   ```

3. Verify state integrity:
   ```bash
   terraform show terraform.tfstate.backup
   ```

4. Restore state:
   ```bash
   cp terraform.tfstate.backup terraform.tfstate
   terraform state push terraform.tfstate
   ```

## Cleanup (DANGER!)

⚠️ **WARNING**: This will delete all state files and history!

Only run this if you're completely done with the project:

```bash
# Navigate to backend directory
cd terraform/backend

# Empty buckets first
aws s3 rm s3://$(terraform output -raw state_bucket_name)/ --recursive
aws s3 rm s3://$(terraform output -raw logs_bucket_name)/ --recursive

# Destroy backend infrastructure
terraform destroy

# Confirm by typing 'yes'
```

## Best Practices

1. ✅ **Never commit state files** to version control
2. ✅ **Use separate state files** for each environment
3. ✅ **Enable MFA delete** on state bucket for production
4. ✅ **Regularly review access logs** for unauthorized access
5. ✅ **Test state recovery** procedures periodically
6. ✅ **Use KMS encryption** for sensitive production workloads
7. ✅ **Monitor DynamoDB locks** for stuck locks
8. ✅ **Set up billing alarms** to catch unexpected costs

## Additional Resources

- [Terraform S3 Backend Documentation](https://developer.hashicorp.com/terraform/language/settings/backends/s3)
- [AWS S3 Best Practices](https://docs.aws.amazon.com/AmazonS3/latest/userguide/security-best-practices.html)
- [DynamoDB Best Practices](https://docs.aws.amazon.com/amazondynamodb/latest/developerguide/best-practices.html)

## Support

For issues or questions:
- Review [../../docs/SETUP.md](../../docs/SETUP.md) for setup guidance
- Check [../../docs/DEPLOYMENT.md](../../docs/DEPLOYMENT.md) for CI/CD integration
- Open an issue on GitHub

---

**Created**: 2026-02-05
**Terraform Version**: >= 1.5.0
**AWS Provider Version**: ~> 5.0
