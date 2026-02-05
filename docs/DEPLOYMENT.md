# Deployment Guide

Complete guide for deploying the Agentic RAG Demo using CI/CD pipelines and managing multiple environments.

## Table of Contents
1. [Deployment Overview](#deployment-overview)
2. [Environment Strategy](#environment-strategy)
3. [GitHub Actions Setup](#github-actions-setup)
4. [CI/CD Workflows](#cicd-workflows)
5. [Manual Deployment](#manual-deployment)
6. [Rollback Procedures](#rollback-procedures)
7. [Monitoring & Alerts](#monitoring--alerts)
8. [Production Readiness Checklist](#production-readiness-checklist)

## Deployment Overview

### Deployment Architecture

```
GitHub Repository
    │
    ├─── Push to feature/* ──────► GitHub Actions: Validate & Test
    │                                     │
    │                                     └─► Terraform validate
    │                                     └─► Terraform plan (dev)
    │                                     └─► Run tests
    │
    ├─── PR to main ─────────────► GitHub Actions: Plan & Preview
    │                                     │
    │                                     └─► Terraform plan (dev)
    │                                     └─► Post plan as PR comment
    │
    ├─── Merge to main ──────────► GitHub Actions: Deploy Dev
    │                                     │
    │                                     └─► Terraform apply (dev)
    │                                     └─► Deploy agent to AgentCore
    │                                     └─► Run smoke tests
    │
    └─── Create Git Tag v*.*.* ──► GitHub Actions: Deploy Prod
                                          │
                                          └─► Terraform plan (prod)
                                          └─► Manual approval required
                                          └─► Terraform apply (prod)
                                          └─► Deploy agent to AgentCore
                                          └─► Run E2E tests
                                          └─► Notify on success/failure
```

### Deployment Principles

1. **Infrastructure as Code**: All infrastructure defined in Terraform
2. **Immutable Deployments**: No manual changes in AWS console
3. **Environment Parity**: Dev and prod use identical Terraform modules
4. **Automated Testing**: Validation at every stage
5. **Manual Approval for Prod**: Human review before production changes
6. **Rollback Capability**: Quick rollback using Terraform state

## Environment Strategy

### Environment Overview

| Environment | Purpose | Trigger | Approval | Monitoring |
|-------------|---------|---------|----------|------------|
| **Dev** | Development and testing | Push to `main` | None | Basic CloudWatch |
| **Prod** | Production workloads | Git tag `v*.*.*` | Required | Full observability |

### Environment Configuration

**Development (dev)**:
- **Purpose**: Feature testing, experimentation
- **Cost**: ~$20-40/month
- **Uptime**: Best effort
- **Data**: Test data only
- **Access**: All developers

**Production (prod)**:
- **Purpose**: Live demo and production use
- **Cost**: Variable based on usage
- **Uptime**: High availability expected
- **Data**: Real data (if applicable)
- **Access**: Limited to DevOps/platform team

### Environment Variables

Each environment has separate configuration:

**terraform/environments/dev/terraform.tfvars**:
```hcl
environment = "dev"
project_name = "agentic-rag-demo"
aws_region = "us-east-1"

# Cost optimization for dev
enable_cloudwatch_detailed_monitoring = false
log_retention_days = 7

tags = {
  Environment = "dev"
  ManagedBy   = "terraform"
  Project     = "agentic-rag-demo"
}
```

**terraform/environments/prod/terraform.tfvars**:
```hcl
environment = "prod"
project_name = "agentic-rag-demo"
aws_region = "us-east-1"

# Production settings
enable_cloudwatch_detailed_monitoring = true
log_retention_days = 30
enable_backup = true

tags = {
  Environment = "prod"
  ManagedBy   = "terraform"
  Project     = "agentic-rag-demo"
  CostCenter  = "demo"
}
```

## GitHub Actions Setup

### 1. Repository Secrets

Configure the following secrets in GitHub repository settings:

**Settings → Secrets and variables → Actions → New repository secret**

| Secret Name | Description | How to Get |
|------------|-------------|------------|
| `AWS_ACCESS_KEY_ID` | AWS access key for deployment | IAM user credentials |
| `AWS_SECRET_ACCESS_KEY` | AWS secret key | IAM user credentials |
| `AWS_REGION` | Default AWS region | e.g., `us-east-1` |
| `AWS_ACCOUNT_ID` | AWS account ID | `aws sts get-caller-identity` |
| `TF_STATE_BUCKET` | Terraform state bucket name | From backend setup |
| `TF_STATE_LOCK_TABLE` | DynamoDB lock table | From backend setup |

**Optional (for notifications)**:
| Secret Name | Description |
|------------|-------------|
| `SLACK_WEBHOOK_URL` | Slack webhook for deployment notifications |
| `DISCORD_WEBHOOK_URL` | Discord webhook for deployment notifications |

### 2. Repository Variables

**Settings → Secrets and variables → Actions → Variables tab**

| Variable Name | Value | Description |
|--------------|-------|-------------|
| `TERRAFORM_VERSION` | `1.5.0` | Terraform version to use |
| `PYTHON_VERSION` | `3.11` | Python version for agent |
| `ENABLE_NOTIFICATIONS` | `true` | Enable Slack/Discord notifications |

### 3. Create GitHub Actions Workflows

Create `.github/workflows/` directory:

```bash
mkdir -p .github/workflows
```

## CI/CD Workflows

### Workflow 1: Terraform Validate (on PR)

**.github/workflows/terraform-validate.yml**:

```yaml
name: Terraform Validate

on:
  pull_request:
    branches: [main]
    paths:
      - 'terraform/**'
      - '.github/workflows/terraform-*.yml'

jobs:
  validate:
    name: Validate Terraform
    runs-on: ubuntu-latest

    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Setup Terraform
        uses: hashicorp/setup-terraform@v3
        with:
          terraform_version: ${{ vars.TERRAFORM_VERSION }}

      - name: Terraform Format Check
        run: terraform fmt -check -recursive
        working-directory: ./terraform

      - name: Terraform Init (Dev)
        run: |
          terraform init \
            -backend-config="bucket=${{ secrets.TF_STATE_BUCKET }}" \
            -backend-config="key=dev/terraform.tfstate" \
            -backend-config="region=${{ secrets.AWS_REGION }}" \
            -backend-config="dynamodb_table=${{ secrets.TF_STATE_LOCK_TABLE }}"
        working-directory: ./terraform/environments/dev
        env:
          AWS_ACCESS_KEY_ID: ${{ secrets.AWS_ACCESS_KEY_ID }}
          AWS_SECRET_ACCESS_KEY: ${{ secrets.AWS_SECRET_ACCESS_KEY }}

      - name: Terraform Validate
        run: terraform validate
        working-directory: ./terraform/environments/dev

      - name: Terraform Plan
        id: plan
        run: terraform plan -no-color -out=tfplan
        working-directory: ./terraform/environments/dev
        env:
          AWS_ACCESS_KEY_ID: ${{ secrets.AWS_ACCESS_KEY_ID }}
          AWS_SECRET_ACCESS_KEY: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
        continue-on-error: true

      - name: Comment PR with Plan
        uses: actions/github-script@v7
        if: github.event_name == 'pull_request'
        with:
          github-token: ${{ secrets.GITHUB_TOKEN }}
          script: |
            const output = `#### Terraform Plan 📖

            <details><summary>Show Plan</summary>

            \`\`\`
            ${{ steps.plan.outputs.stdout }}
            \`\`\`

            </details>

            *Pushed by: @${{ github.actor }}, Action: \`${{ github.event_name }}\`*`;

            github.rest.issues.createComment({
              issue_number: context.issue.number,
              owner: context.repo.owner,
              repo: context.repo.repo,
              body: output
            })
```

### Workflow 2: Deploy to Dev (on merge to main)

**.github/workflows/deploy-dev.yml**:

```yaml
name: Deploy to Dev

on:
  push:
    branches: [main]
    paths:
      - 'terraform/**'
      - 'agent/**'
      - '.github/workflows/deploy-dev.yml'

jobs:
  deploy:
    name: Deploy Development Environment
    runs-on: ubuntu-latest
    environment: development

    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Setup Terraform
        uses: hashicorp/setup-terraform@v3
        with:
          terraform_version: ${{ vars.TERRAFORM_VERSION }}

      - name: Setup Python
        uses: actions/setup-python@v5
        with:
          python-version: ${{ vars.PYTHON_VERSION }}

      - name: Configure AWS Credentials
        uses: aws-actions/configure-aws-credentials@v4
        with:
          aws-access-key-id: ${{ secrets.AWS_ACCESS_KEY_ID }}
          aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
          aws-region: ${{ secrets.AWS_REGION }}

      - name: Terraform Init
        run: |
          terraform init \
            -backend-config="bucket=${{ secrets.TF_STATE_BUCKET }}" \
            -backend-config="key=dev/terraform.tfstate" \
            -backend-config="region=${{ secrets.AWS_REGION }}" \
            -backend-config="dynamodb_table=${{ secrets.TF_STATE_LOCK_TABLE }}"
        working-directory: ./terraform/environments/dev

      - name: Terraform Plan
        id: plan
        run: terraform plan -out=tfplan
        working-directory: ./terraform/environments/dev

      - name: Terraform Apply
        run: terraform apply -auto-approve tfplan
        working-directory: ./terraform/environments/dev

      - name: Save Terraform Outputs
        run: terraform output -json > ../../../outputs-dev.json
        working-directory: ./terraform/environments/dev

      - name: Install Agent Dependencies
        run: pip install -r requirements.txt
        working-directory: ./agent/strands-agent

      - name: Package Agent
        run: |
          zip -r agent.zip src/ requirements.txt
        working-directory: ./agent/strands-agent

      - name: Deploy Agent to AgentCore
        run: |
          AGENT_ID=$(jq -r '.agent_id.value' outputs-dev.json)
          BUCKET=$(jq -r '.documents_bucket_name.value' outputs-dev.json)

          aws s3 cp agent/strands-agent/agent.zip s3://${BUCKET}/agent/

          # Update agent (commands will vary based on AgentCore deployment method)
          echo "Agent deployed to AgentCore: ${AGENT_ID}"

      - name: Run Smoke Tests
        run: |
          pip install pytest boto3
          pytest tests/smoke/ -v
        continue-on-error: true

      - name: Notify on Success
        if: success() && vars.ENABLE_NOTIFICATIONS == 'true'
        run: |
          curl -X POST ${{ secrets.SLACK_WEBHOOK_URL }} \
            -H 'Content-Type: application/json' \
            -d '{
              "text": "✅ Dev deployment successful",
              "blocks": [
                {
                  "type": "section",
                  "text": {
                    "type": "mrkdwn",
                    "text": "*Deployment to Dev Environment Succeeded* ✅\n*Commit:* ${{ github.sha }}\n*Author:* ${{ github.actor }}"
                  }
                }
              ]
            }'

      - name: Notify on Failure
        if: failure() && vars.ENABLE_NOTIFICATIONS == 'true'
        run: |
          curl -X POST ${{ secrets.SLACK_WEBHOOK_URL }} \
            -H 'Content-Type: application/json' \
            -d '{
              "text": "❌ Dev deployment failed",
              "blocks": [
                {
                  "type": "section",
                  "text": {
                    "type": "mrkdwn",
                    "text": "*Deployment to Dev Environment Failed* ❌\n*Commit:* ${{ github.sha }}\n*Author:* ${{ github.actor }}\n*See:* ${{ github.server_url }}/${{ github.repository }}/actions/runs/${{ github.run_id }}"
                  }
                }
              ]
            }'
```

### Workflow 3: Deploy to Production (on Git tag)

**.github/workflows/deploy-prod.yml**:

```yaml
name: Deploy to Production

on:
  push:
    tags:
      - 'v*.*.*'

jobs:
  deploy:
    name: Deploy Production Environment
    runs-on: ubuntu-latest
    environment:
      name: production
      url: https://your-production-url.com

    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Setup Terraform
        uses: hashicorp/setup-terraform@v3
        with:
          terraform_version: ${{ vars.TERRAFORM_VERSION }}

      - name: Setup Python
        uses: actions/setup-python@v5
        with:
          python-version: ${{ vars.PYTHON_VERSION }}

      - name: Configure AWS Credentials
        uses: aws-actions/configure-aws-credentials@v4
        with:
          aws-access-key-id: ${{ secrets.AWS_ACCESS_KEY_ID }}
          aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
          aws-region: ${{ secrets.AWS_REGION }}

      - name: Terraform Init
        run: |
          terraform init \
            -backend-config="bucket=${{ secrets.TF_STATE_BUCKET }}" \
            -backend-config="key=prod/terraform.tfstate" \
            -backend-config="region=${{ secrets.AWS_REGION }}" \
            -backend-config="dynamodb_table=${{ secrets.TF_STATE_LOCK_TABLE }}"
        working-directory: ./terraform/environments/prod

      - name: Terraform Plan
        id: plan
        run: |
          terraform plan -out=tfplan
          terraform show -no-color tfplan > plan-output.txt
        working-directory: ./terraform/environments/prod

      - name: Review Plan
        run: |
          echo "::group::Terraform Plan Output"
          cat terraform/environments/prod/plan-output.txt
          echo "::endgroup::"

      # Manual approval happens here via GitHub Environment protection rules

      - name: Terraform Apply
        run: terraform apply -auto-approve tfplan
        working-directory: ./terraform/environments/prod

      - name: Save Terraform Outputs
        run: terraform output -json > ../../../outputs-prod.json
        working-directory: ./terraform/environments/prod

      - name: Install Agent Dependencies
        run: pip install -r requirements.txt
        working-directory: ./agent/strands-agent

      - name: Package Agent
        run: |
          zip -r agent.zip src/ requirements.txt
        working-directory: ./agent/strands-agent

      - name: Deploy Agent to AgentCore
        run: |
          AGENT_ID=$(jq -r '.agent_id.value' outputs-prod.json)
          BUCKET=$(jq -r '.documents_bucket_name.value' outputs-prod.json)

          aws s3 cp agent/strands-agent/agent.zip s3://${BUCKET}/agent/

          echo "Agent deployed to AgentCore: ${AGENT_ID}"

      - name: Run E2E Tests
        run: |
          pip install pytest boto3
          pytest tests/e2e/ -v
        continue-on-error: false

      - name: Create GitHub Release
        uses: softprops/action-gh-release@v1
        with:
          tag_name: ${{ github.ref_name }}
          name: Release ${{ github.ref_name }}
          body: |
            ## Changes in this Release

            Production deployment of version ${{ github.ref_name }}

            ### Deployed Resources
            - Agent ID: $(jq -r '.agent_id.value' outputs-prod.json)
            - Documents Bucket: $(jq -r '.documents_bucket_name.value' outputs-prod.json)

            ### Deployment Info
            - Deployed by: ${{ github.actor }}
            - Commit: ${{ github.sha }}
          draft: false
          prerelease: false

      - name: Notify on Success
        if: success()
        run: |
          curl -X POST ${{ secrets.SLACK_WEBHOOK_URL }} \
            -H 'Content-Type: application/json' \
            -d '{
              "text": "🚀 Production deployment successful",
              "blocks": [
                {
                  "type": "section",
                  "text": {
                    "type": "mrkdwn",
                    "text": "*Production Deployment Succeeded* 🚀\n*Version:* ${{ github.ref_name }}\n*Commit:* ${{ github.sha }}\n*Deployed by:* ${{ github.actor }}"
                  }
                }
              ]
            }'

      - name: Notify on Failure
        if: failure()
        run: |
          curl -X POST ${{ secrets.SLACK_WEBHOOK_URL }} \
            -H 'Content-Type: application/json' \
            -d '{
              "text": "🚨 Production deployment failed",
              "blocks": [
                {
                  "type": "section",
                  "text": {
                    "type": "mrkdwn",
                    "text": "*Production Deployment Failed* 🚨\n*Version:* ${{ github.ref_name }}\n*Commit:* ${{ github.sha }}\n*Deployed by:* ${{ github.actor }}\n*Action Required:* Immediate investigation needed\n*See:* ${{ github.server_url }}/${{ github.repository }}/actions/runs/${{ github.run_id }}"
                  }
                }
              ]
            }'
```

### Workflow 4: Cost Estimation (on PR)

**.github/workflows/cost-estimate.yml**:

```yaml
name: Terraform Cost Estimation

on:
  pull_request:
    branches: [main]
    paths:
      - 'terraform/**'

jobs:
  cost-estimate:
    name: Estimate Infrastructure Costs
    runs-on: ubuntu-latest

    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Setup Infracost
        uses: infracost/actions/setup@v3
        with:
          api-key: ${{ secrets.INFRACOST_API_KEY }}

      - name: Generate Infracost JSON
        run: |
          infracost breakdown \
            --path=terraform/environments/dev \
            --format=json \
            --out-file=/tmp/infracost.json

      - name: Comment PR with Cost Estimate
        uses: infracost/actions/comment@v1
        with:
          path: /tmp/infracost.json
          behavior: update
```

## Manual Deployment

### Deploy to Dev Manually

```bash
# Navigate to dev environment
cd terraform/environments/dev

# Initialize Terraform
terraform init \
  -backend-config="bucket=${TF_STATE_BUCKET}" \
  -backend-config="key=dev/terraform.tfstate" \
  -backend-config="region=${AWS_REGION}" \
  -backend-config="dynamodb_table=${TF_STATE_LOCK_TABLE}"

# Plan changes
terraform plan -out=tfplan

# Review the plan carefully
terraform show tfplan

# Apply changes
terraform apply tfplan

# Save outputs
terraform output -json > ../../../outputs-dev.json
```

### Deploy to Production Manually

```bash
# Navigate to prod environment
cd terraform/environments/prod

# Initialize Terraform
terraform init \
  -backend-config="bucket=${TF_STATE_BUCKET}" \
  -backend-config="key=prod/terraform.tfstate" \
  -backend-config="region=${AWS_REGION}" \
  -backend-config="dynamodb_table=${TF_STATE_LOCK_TABLE}"

# Plan changes
terraform plan -out=tfplan

# Review the plan with team
terraform show tfplan

# ⚠️ IMPORTANT: Get approval before proceeding

# Apply changes
terraform apply tfplan

# Save outputs
terraform output -json > ../../../outputs-prod.json

# Tag the release
git tag -a v1.0.0 -m "Production release v1.0.0"
git push origin v1.0.0
```

## Rollback Procedures

### Quick Rollback Using Terraform

**Scenario**: Recently deployed changes caused issues

```bash
# 1. Navigate to environment
cd terraform/environments/prod

# 2. Check Terraform state history
terraform state list

# 3. Revert to previous state (if available)
# Note: This requires state versioning enabled on S3 bucket

# Download previous state version
aws s3api list-object-versions \
  --bucket ${TF_STATE_BUCKET} \
  --prefix prod/terraform.tfstate

# Restore specific version
aws s3api get-object \
  --bucket ${TF_STATE_BUCKET} \
  --key prod/terraform.tfstate \
  --version-id <PREVIOUS_VERSION_ID> \
  terraform.tfstate.backup

# 4. Alternative: Roll forward with previous code
git log --oneline
git checkout <PREVIOUS_COMMIT_SHA>

# 5. Re-deploy
terraform plan -out=tfplan
terraform apply tfplan
```

### Rollback Using Git Tags

**Scenario**: Need to revert to previous release

```bash
# 1. List recent tags
git tag -l --sort=-v:refname | head -n 5

# 2. Checkout previous tag
git checkout v1.0.0

# 3. Trigger deployment
git tag -a v1.0.1-rollback -m "Rollback to v1.0.0"
git push origin v1.0.1-rollback

# This triggers the production deployment workflow
```

### Emergency Rollback

**Scenario**: Critical issue requiring immediate action

```bash
# 1. Disable agent immediately (if needed)
aws bedrock-agent update-agent \
  --agent-id <AGENT_ID> \
  --agent-name <AGENT_NAME> \
  --agent-status DISABLED \
  --region ${AWS_REGION}

# 2. Revert infrastructure
cd terraform/environments/prod
terraform destroy -target=aws_bedrock_agent.rag_agent

# 3. Investigate issue offline

# 4. Re-deploy when fixed
terraform apply
```

## Monitoring & Alerts

### CloudWatch Dashboards

Create monitoring dashboards for each environment:

```bash
# Create CloudWatch dashboard
aws cloudwatch put-dashboard \
  --dashboard-name agentic-rag-demo-prod \
  --dashboard-body file://cloudwatch-dashboard.json
```

**cloudwatch-dashboard.json**:
```json
{
  "widgets": [
    {
      "type": "metric",
      "properties": {
        "title": "Agent Invocations",
        "metrics": [
          ["AWS/BedrockAgent", "Invocations", {"stat": "Sum"}]
        ],
        "period": 300,
        "region": "us-east-1"
      }
    },
    {
      "type": "metric",
      "properties": {
        "title": "Agent Errors",
        "metrics": [
          ["AWS/BedrockAgent", "Errors", {"stat": "Sum"}]
        ],
        "period": 300,
        "region": "us-east-1"
      }
    },
    {
      "type": "metric",
      "properties": {
        "title": "Bedrock API Latency",
        "metrics": [
          ["AWS/Bedrock", "InvocationLatency", {"stat": "Average"}]
        ],
        "period": 300,
        "region": "us-east-1"
      }
    },
    {
      "type": "log",
      "properties": {
        "title": "Recent Agent Logs",
        "query": "SOURCE '/aws/agentcore/agentic-rag-demo-agent' | fields @timestamp, @message | sort @timestamp desc | limit 20",
        "region": "us-east-1"
      }
    }
  ]
}
```

### CloudWatch Alarms

```bash
# Create alarm for agent errors
aws cloudwatch put-metric-alarm \
  --alarm-name agentic-rag-demo-agent-errors-prod \
  --alarm-description "Alert on agent errors" \
  --metric-name Errors \
  --namespace AWS/BedrockAgent \
  --statistic Sum \
  --period 300 \
  --evaluation-periods 1 \
  --threshold 5 \
  --comparison-operator GreaterThanThreshold \
  --alarm-actions arn:aws:sns:us-east-1:123456789012:alerts

# Create alarm for high costs
aws cloudwatch put-metric-alarm \
  --alarm-name agentic-rag-demo-high-costs-prod \
  --alarm-description "Alert on high daily costs" \
  --metric-name EstimatedCharges \
  --namespace AWS/Billing \
  --statistic Maximum \
  --period 86400 \
  --evaluation-periods 1 \
  --threshold 100 \
  --comparison-operator GreaterThanThreshold \
  --alarm-actions arn:aws:sns:us-east-1:123456789012:billing-alerts
```

### Cost Monitoring

```bash
# Set up cost budget
aws budgets create-budget \
  --account-id $(aws sts get-caller-identity --query Account --output text) \
  --budget file://cost-budget.json \
  --notifications-with-subscribers file://budget-notifications.json
```

## Production Readiness Checklist

Before deploying to production:

### Infrastructure

- [ ] Terraform state backend configured with versioning
- [ ] All resources tagged appropriately (Project, Environment, ManagedBy)
- [ ] IAM roles follow least privilege principle
- [ ] S3 buckets have encryption enabled
- [ ] CloudWatch Logs retention configured (30 days for prod)
- [ ] Cost budgets and alerts configured

### Security

- [ ] Bedrock model access enabled in target region
- [ ] No hardcoded ARNs or account IDs in code
- [ ] Secrets stored in GitHub Secrets (not in code)
- [ ] IAM policies reviewed for over-permissive access
- [ ] S3 bucket policies restrict public access
- [ ] CloudTrail enabled for audit logging

### CI/CD

- [ ] GitHub Actions workflows tested in dev
- [ ] Manual approval required for production deployments
- [ ] Rollback procedures documented and tested
- [ ] Notification webhooks configured (Slack/Discord)
- [ ] Cost estimation integrated into PR workflow

### Monitoring

- [ ] CloudWatch dashboard created
- [ ] CloudWatch alarms configured for errors
- [ ] Cost monitoring alerts set up
- [ ] Log retention policies defined
- [ ] SNS topics created for alerts

### Testing

- [ ] Smoke tests passing in dev
- [ ] E2E tests written and passing
- [ ] Load testing completed (if applicable)
- [ ] Rollback procedure tested successfully

### Documentation

- [ ] README.md updated
- [ ] ARCHITECTURE.md reviewed
- [ ] SETUP.md validated by team member
- [ ] DEPLOYMENT.md covers all scenarios
- [ ] Runbook created for common issues

### Operational

- [ ] On-call rotation defined (if applicable)
- [ ] Incident response plan documented
- [ ] Backup and disaster recovery plan defined
- [ ] Change management process established

## Deployment Workflow Example

### Complete Production Deployment Flow

```bash
# 1. Create feature branch
git checkout -b feature/new-capability

# 2. Make changes to Terraform or agent code
# ... edit files ...

# 3. Commit and push
git add .
git commit -m "feat: add new capability"
git push origin feature/new-capability

# 4. Create Pull Request
# GitHub Actions will run:
# - Terraform validate
# - Terraform plan (dev)
# - Cost estimation
# - Post results as PR comment

# 5. Review and merge PR
# After merge to main, GitHub Actions will:
# - Deploy to dev environment
# - Run smoke tests
# - Notify on Slack

# 6. Test in dev environment
# ... manual testing ...

# 7. Create production release
git checkout main
git pull origin main
git tag -a v1.0.0 -m "Release v1.0.0: New capability"
git push origin v1.0.0

# 8. GitHub Actions triggers production deployment
# - Plans infrastructure changes
# - Waits for manual approval
# - Applies changes after approval
# - Runs E2E tests
# - Creates GitHub release
# - Notifies on Slack

# 9. Verify production deployment
# ... manual verification ...

# 10. Monitor for issues
# ... check CloudWatch dashboards ...
```

---

**Document Version**: 1.0
**Last Updated**: 2026-02-05
**Maintained By**: DevOps Team
