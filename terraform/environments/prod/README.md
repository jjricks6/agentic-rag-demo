# Production Environment

Terraform configuration for the production environment of the Agentic RAG Demo.

## Overview

This environment is optimized for:
- **High Availability**: Production-grade settings
- **Data Protection**: Versioning enabled, backup support
- **Security**: Strict access controls, enhanced monitoring
- **Cost Optimization**: Glacier transitions, reserved Lambda concurrency
- **Observability**: Full monitoring, alarms, and dashboards

## Prerequisites

⚠️ **Critical**: Production deployment requires careful planning

Before deploying:

1. ✅ **Dev environment tested**: Thoroughly test in dev first
2. ✅ **Backend created**: Run `terraform apply` in `../../backend/`
3. ✅ **AWS credentials configured**: Production AWS account
4. ✅ **Bedrock models enabled**: In production account/region
5. ✅ **SNS topics created**: For alarm notifications
6. ✅ **Backup plan created** (if using AWS Backup)
7. ✅ **Cost budgets set**: Configure billing alarms
8. ✅ **Team approval**: Get sign-off before deploying

## Deployment Process

### 1. Copy and Configure

```bash
cd terraform/environments/prod
cp terraform.tfvars.example terraform.tfvars

# ⚠️  Edit terraform.tfvars carefully - this is production!
# Update:
# - cors_allowed_origins (your production domain)
# - alarm_sns_topic_arns (your alert channels)
# - tags (cost center, owner, etc.)
```

### 2. Create SNS Topics (if not exists)

```bash
# Create SNS topic for alerts
aws sns create-topic \
  --name agentic-rag-demo-prod-alerts \
  --region us-east-1

# Subscribe to email alerts
aws sns subscribe \
  --topic-arn arn:aws:sns:us-east-1:ACCOUNT_ID:agentic-rag-demo-prod-alerts \
  --protocol email \
  --notification-endpoint ops-team@example.com

# Confirm subscription in email
```

### 3. Build Production Lambda Functions

```bash
cd ../../../agent/lambda
./build.sh --environment prod

# Verify zip files created
ls -lh *.zip
```

### 4. Initialize Terraform

```bash
cd ../../terraform/environments/prod

# Auto-generate backend config (if not already done)
cd ../../scripts
./generate-backend-configs.sh
cd ../environments/prod

# Initialize with backend config file
terraform init -backend-config=backend.hcl

# Note: backend.hcl is auto-generated and gitignored
# For CI/CD pipelines, see terraform/scripts/README.md
```

### 5. Plan Changes

```bash
# Generate plan
terraform plan -out=prod.tfplan

# ⚠️  REVIEW CAREFULLY
terraform show prod.tfplan

# Save plan for team review
terraform show -no-color prod.tfplan > plan-output.txt
```

### 6. Get Team Approval

**Checklist before applying**:
- [ ] Plan reviewed by at least 2 team members
- [ ] No unexpected resource deletions
- [ ] Cost estimate reviewed
- [ ] SNS alerts configured and tested
- [ ] Backup plan configured (if required)
- [ ] Rollback procedure documented

### 7. Apply (Production Deployment)

```bash
# ⚠️  This deploys to production!
terraform apply prod.tfplan

# Save outputs
terraform output -json > ../../../agent-config-prod.json
```

### 8. Post-Deployment Verification

```bash
# 1. Verify agent is READY
aws bedrock-agent get-agent \
  --agent-id $(terraform output -raw agent_id) \
  --query 'agent.{Status:agentStatus,Name:agentName}' \
  --output table

# 2. Test agent invocation
aws bedrock-agent-runtime invoke-agent \
  --agent-id $(terraform output -raw agent_id) \
  --agent-alias-id $(terraform output -raw agent_alias_id) \
  --session-id prod-test-$(date +%s) \
  --input-text "System check - are you operational?" \
  --region us-east-1 \
  response.json

# 3. Check CloudWatch dashboard
# Visit URL from: terraform output -raw aws_console_links

# 4. Verify alarms are active
aws cloudwatch describe-alarms \
  --alarm-name-prefix agentic-rag-demo-prod \
  --query 'MetricAlarms[].{Name:AlarmName,State:StateValue}' \
  --output table
```

## What Gets Deployed

| Resource | Purpose | Production Settings |
|----------|---------|---------------------|
| S3 Bucket | Document storage | Versioning ON, Glacier enabled |
| S3 Vector Bucket | Vector embeddings | HNSW optimized (M=32) |
| Vector Index | Similarity search | ef_search=200 (high accuracy) |
| Bedrock Agent | Orchestration | Claude 3.5 Sonnet |
| 2x Lambda | Action handlers | 1GB memory, reserved concurrency |
| CloudWatch Logs | Monitoring | 90-day retention |
| CloudWatch Alarms | Alerting | Error, latency, dead agent |
| CloudWatch Dashboard | Visualization | Full metrics |
| IAM Roles | Security | Least privilege |

## Production Costs (Estimated)

**Base infrastructure** (always-on):
- S3 storage: ~$1-5/month
- CloudWatch Logs: ~$5-10/month
- Lambda (reserved): ~$5/month
- **Total: ~$11-20/month**

**Usage costs** (varies):
- Bedrock LLM (10K requests): ~$30-150/month
- Bedrock Embeddings (1K docs): ~$1/month
- S3 Vectors searches (10K): ~$50-100/month
- **Total usage: ~$80-250/month**

**Combined estimate**: ~$100-270/month for moderate production use

## Monitoring

### CloudWatch Dashboard

Access your dashboard:
```bash
# Get dashboard URL
terraform output -json aws_console_links | jq -r '.cloudwatch_dashboard'
```

Dashboard shows:
- Agent invocation rate
- Error count and rate
- Response latency (avg, p50, p99)
- Recent log entries

### CloudWatch Alarms

Production alarms configured:

1. **High Error Rate**: >5 errors in 10 minutes
2. **High Latency**: >5 seconds average over 10 minutes
3. **No Invocations**: No calls for 3 hours (dead agent)
4. **Storage Size**: >100 GB threshold
5. **Vector Count**: >1M vectors

All alarms send notifications to configured SNS topics.

### Log Queries

```bash
# View recent errors
aws logs tail $(terraform output -raw log_group_name) \
  --follow \
  --filter-pattern "ERROR"

# Query with CloudWatch Insights
aws logs start-query \
  --log-group-name $(terraform output -raw log_group_name) \
  --start-time $(date -u -d '1 hour ago' +%s) \
  --end-time $(date -u +%s) \
  --query-string 'fields @timestamp, @message | filter @message like /ERROR/ | sort @timestamp desc'
```

## Rollback Procedure

If deployment fails or issues arise:

### Option 1: Rollback via Terraform State

```bash
# View state versions
aws s3api list-object-versions \
  --bucket ${BACKEND_BUCKET} \
  --prefix prod/terraform.tfstate

# Download previous version
aws s3api get-object \
  --bucket ${BACKEND_BUCKET} \
  --key prod/terraform.tfstate \
  --version-id <PREVIOUS_VERSION_ID> \
  terraform.tfstate.backup

# Restore and apply
mv terraform.tfstate.backup terraform.tfstate
terraform state push terraform.tfstate
terraform plan
terraform apply
```

### Option 2: Emergency Agent Disable

```bash
# Immediately disable agent
aws bedrock-agent update-agent \
  --agent-id $(terraform output -raw agent_id) \
  --agent-status DISABLED \
  --region us-east-1

# Investigate issue
# Fix and re-enable
```

## Maintenance

### Update Lambda Functions

```bash
# Build new Lambda code
cd ../../../agent/lambda
./build.sh --environment prod

# Update functions
cd ../../terraform/environments/prod
terraform apply \
  -target=aws_lambda_function.document_handler \
  -target=aws_lambda_function.search_handler
```

### Review Access Logs

```bash
# Download S3 access logs (if enabled)
aws s3 sync \
  s3://$(terraform output -raw documents_bucket_name)-logs/ \
  ./access-logs/

# Analyze with CloudWatch Insights
```

### Cost Review

```bash
# Check current month costs
aws ce get-cost-and-usage \
  --time-period Start=$(date -u -d '1 month ago' +%Y-%m-%d),End=$(date -u +%Y-%m-%d) \
  --granularity MONTHLY \
  --metrics BlendedCost \
  --filter file://cost-filter.json

# cost-filter.json:
# {"Tags": {"Key": "Environment", "Values": ["prod"]}}
```

## Security Checklist

Before going live:

- [ ] All S3 buckets have public access blocked
- [ ] IAM roles follow least privilege
- [ ] CloudTrail enabled for audit logging
- [ ] SNS alert subscriptions confirmed
- [ ] Bedrock guardrails configured (if needed)
- [ ] CORS origins restricted to production domains only
- [ ] Lambda functions using latest runtime
- [ ] No secrets in code or logs
- [ ] Cost budgets and alarms configured

## Disaster Recovery

### Backup Strategy

1. **S3 Versioning**: 90-day retention for documents
2. **State Backup**: Automatic S3 versioning on Terraform state
3. **AWS Backup** (optional): Configure for critical data

### Recovery Procedure

1. Identify issue scope (agent, storage, vectors)
2. Check CloudWatch logs for root cause
3. If data loss: Restore from S3 versions or AWS Backup
4. If configuration issue: Rollback via Terraform
5. If code issue: Deploy previous Lambda version
6. Test recovery thoroughly
7. Document incident

## Support

For production issues:

1. **Check alarms**: Review CloudWatch alarm history
2. **Review logs**: CloudWatch Logs Insights queries
3. **Check status**: AWS Service Health Dashboard
4. **Contact team**: Escalate if needed

## Additional Resources

- [../../docs/DEPLOYMENT.md](../../docs/DEPLOYMENT.md) - Full deployment guide
- [../../docs/ARCHITECTURE.md](../../docs/ARCHITECTURE.md) - System architecture
- [../dev/README.md](../dev/README.md) - Dev environment docs

---

**Environment**: Production
**Last Updated**: 2026-02-05
**Criticality**: HIGH
**Terraform Version**: >= 1.5.0
