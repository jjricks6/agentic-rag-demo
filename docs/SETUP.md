# Setup Guide

Complete step-by-step instructions for deploying Recall in your AWS account.

## Table of Contents
1. [Prerequisites](#prerequisites)
2. [AWS Account Setup](#aws-account-setup)
3. [Local Development Environment](#local-development-environment)
4. [Terraform Backend Setup](#terraform-backend-setup)
5. [Deploy Infrastructure](#deploy-infrastructure)
6. [Configure and Run the Agent](#configure-and-run-the-agent)
7. [Run the Streamlit UI](#run-the-streamlit-ui)
8. [Verification and Testing](#verification-and-testing)
9. [Troubleshooting](#troubleshooting)

## Prerequisites

### Required Tools

Ensure you have the following tools installed on your local machine:

| Tool | Minimum Version | Installation |
|------|----------------|--------------|
| AWS CLI | 2.x | [Install Guide](https://docs.aws.amazon.com/cli/latest/userguide/install-cliv2.html) |
| Terraform | 1.5.0+ | [Install Guide](https://developer.hashicorp.com/terraform/install) |
| Python | 3.11+ | [Install Guide](https://www.python.org/downloads/) |
| Git | 2.x | [Install Guide](https://git-scm.com/downloads) |
| pip | Latest | Included with Python |

### Verify Installation

```bash
# Check AWS CLI
aws --version
# Expected: aws-cli/2.x.x

# Check Terraform
terraform --version
# Expected: Terraform v1.5.0 or higher

# Check Python
python3 --version
# Expected: Python 3.11.x or higher

# Check Git
git --version
# Expected: git version 2.x.x
```

### AWS Account Requirements

- **Active AWS Account**: [Create one here](https://aws.amazon.com/free/)
- **IAM User or Role** with administrator access (or specific permissions listed below)
- **AWS Region**: Choose a region that supports Bedrock (recommended: `us-east-1`, `us-west-2`)

### Required AWS Permissions

Your IAM user/role needs permissions for:
- S3 (create buckets, upload objects)
- S3 Tables (for S3 Vectors)
- Bedrock (invoke models, manage agents)
- AgentCore (create and manage agents)
- IAM (create roles and policies)
- CloudWatch Logs (create log groups)
- DynamoDB (for Terraform state locking)

**Recommended**: Use `AdministratorAccess` for initial setup, then restrict for production.

## AWS Account Setup

### 1. Configure AWS CLI

```bash
# Configure AWS CLI with your credentials
aws configure

# You'll be prompted for:
# AWS Access Key ID: [Your access key]
# AWS Secret Access Key: [Your secret key]
# Default region name: us-east-1
# Default output format: json
```

**Verify configuration:**
```bash
# Check current identity
aws sts get-caller-identity

# Expected output:
# {
#     "UserId": "AIDAXXXXXXXXXX",
#     "Account": "123456789012",
#     "Arn": "arn:aws:iam::123456789012:user/your-username"
# }
```

### 2. Enable Bedrock Model Access

Bedrock models require explicit opt-in before use.

**Via AWS Console:**
1. Navigate to [Amazon Bedrock Console](https://console.aws.amazon.com/bedrock)
2. Select your region (e.g., `us-east-1`)
3. Click "Model access" in the left sidebar
4. Click "Manage model access"
5. Enable the following models:
   - ✅ **Amazon Titan Embeddings G1 - Text v2**
   - ✅ **Anthropic Claude 3.5 Sonnet**
6. Click "Request model access"
7. Wait for approval (usually instant for Titan, may take a few minutes for Claude)

**Via AWS CLI:**
```bash
# Check current model access
aws bedrock list-foundation-models \
  --region us-east-1 \
  --query 'modelSummaries[?contains(modelId, `titan-embed`) || contains(modelId, `claude-3-5-sonnet`)].{Model:modelId,Status:modelLifecycle.status}'

# Note: Model access must be enabled via console for first-time setup
```

### 3. Set Environment Variables

Create a `.env` file for local development:

```bash
# Copy the example environment file
cp .env.example .env

# Edit with your values
cat > .env << EOF
# AWS Configuration
AWS_REGION=us-east-1
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

# Project Configuration
PROJECT_NAME=agentic-rag-demo
ENVIRONMENT=dev

# Terraform State Backend (will create these)
TF_STATE_BUCKET=${PROJECT_NAME}-tfstate-${AWS_ACCOUNT_ID}
TF_STATE_LOCK_TABLE=${PROJECT_NAME}-tfstate-lock

# Bedrock Configuration
BEDROCK_EMBEDDING_MODEL=amazon.titan-embed-text-v2:0
BEDROCK_LLM_MODEL=us.anthropic.claude-3-5-sonnet-20241022-v2:0

# Agent Configuration
AGENT_NAME=${PROJECT_NAME}-agent
CHUNK_SIZE=5000
CHUNK_OVERLAP=1000
TOP_K_RESULTS=5
EOF
```

**Load environment variables:**
```bash
# For bash/zsh
source .env

# Verify
echo $AWS_REGION
echo $AWS_ACCOUNT_ID
```

## Local Development Environment

### 1. Clone the Repository

```bash
# Clone the repo
git clone https://github.com/yourusername/agentic-rag-demo.git
cd agentic-rag-demo

# Verify structure
ls -la
# Should see: terraform/, agent/, ui/, docs/, README.md
```

### 2. Install Python Dependencies

```bash
# Create a virtual environment
python3 -m venv venv

# Activate virtual environment
# On macOS/Linux:
source venv/bin/activate

# On Windows:
# venv\Scripts\activate

# Upgrade pip
pip install --upgrade pip

# Install agent dependencies
cd agent/strands-agent
pip install -r requirements.txt

# Install UI dependencies
cd ../../ui/streamlit-app
pip install -r requirements.txt

# Return to root
cd ../..
```

### 3. Verify Python Setup

```bash
# Check installed packages
pip list | grep -E "boto3|streamlit|strands"

# Expected packages:
# boto3                 1.34.x
# streamlit            1.31.x
# strands-agent-framework  x.x.x (or similar)
```

## Terraform Backend Setup

The Terraform backend stores infrastructure state in S3 with DynamoDB locking.

### 1. Create Backend Infrastructure

```bash
# Navigate to backend directory
cd terraform/backend

# Review the backend configuration
cat backend.tf

# Initialize Terraform
terraform init

# Plan the backend resources
terraform plan

# Expected output:
# + aws_s3_bucket.tfstate
# + aws_dynamodb_table.tfstate_lock
# + aws_s3_bucket_versioning.tfstate_versioning
# + aws_s3_bucket_server_side_encryption_configuration.tfstate_encryption
```

### 2. Apply Backend Configuration

```bash
# Create the backend resources
terraform apply

# Review the plan and type 'yes' to confirm

# Expected output:
# Apply complete! Resources: 4 added, 0 changed, 0 destroyed.
#
# Outputs:
# state_bucket_name = "agentic-rag-demo-tfstate-123456789012"
# state_lock_table_name = "agentic-rag-demo-tfstate-lock"
```

### 3. Verify Backend Creation

```bash
# Check S3 bucket
aws s3 ls | grep tfstate

# Check DynamoDB table
aws dynamodb describe-table \
  --table-name agentic-rag-demo-tfstate-lock \
  --query 'Table.{Name:TableName,Status:TableStatus}' \
  --output table

# Expected:
# --------------------------------
# |        DescribeTable         |
# +------+-----------------------+
# | Name | agentic-rag-demo-tfstate-lock |
# | Status| ACTIVE              |
# +------+-----------------------+
```

## Deploy Infrastructure

### 1. Configure Development Environment

```bash
# Navigate to dev environment
cd ../environments/dev

# Review variables
cat variables.tf

# Create terraform.tfvars with your values
cat > terraform.tfvars << EOF
aws_region     = "us-east-1"
environment    = "dev"
project_name   = "agentic-rag-demo"

# S3 Configuration
documents_bucket_prefix = "documents"

# Bedrock Configuration
embedding_model_id = "amazon.titan-embed-text-v2:0"
llm_model_id      = "us.anthropic.claude-3-5-sonnet-20241022-v2:0"

# Agent Configuration
agent_name          = "agentic-rag-demo-agent"
chunk_size          = 5000
chunk_overlap       = 1000
top_k_results       = 5
vector_dimensions   = 1024

# Tags
tags = {
  Project     = "agentic-rag-demo"
  Environment = "dev"
  ManagedBy   = "terraform"
}
EOF
```

### 2. Initialize Terraform

```bash
# Initialize with backend configuration
terraform init \
  -backend-config="bucket=agentic-rag-demo-tfstate-${AWS_ACCOUNT_ID}" \
  -backend-config="key=dev/terraform.tfstate" \
  -backend-config="region=${AWS_REGION}" \
  -backend-config="dynamodb_table=agentic-rag-demo-tfstate-lock"

# Expected output:
# Terraform has been successfully initialized!
```

### 3. Plan Infrastructure

```bash
# Run terraform plan
terraform plan -out=tfplan

# Review the plan carefully
# Expected resources:
# + aws_s3_bucket.documents          (document storage)
# + aws_s3_bucket.vectors            (vector storage)
# + aws_iam_role.agent_role          (agent IAM role)
# + aws_iam_policy.agent_policy      (agent permissions)
# + aws_bedrock_agent.rag_agent      (AgentCore agent)
# + aws_cloudwatch_log_group.agent_logs (logging)
# + Additional supporting resources
```

### 4. Apply Infrastructure

```bash
# Apply the plan
terraform apply tfplan

# Expected output:
# Apply complete! Resources: 15 added, 0 changed, 0 destroyed.
#
# Outputs:
# agent_id = "ABCDEFGHIJ"
# agent_arn = "arn:aws:bedrock:us-east-1:123456789012:agent/ABCDEFGHIJ"
# documents_bucket_name = "agentic-rag-demo-documents-dev-123456789012"
# vectors_bucket_name = "agentic-rag-demo-vectors-dev-123456789012"
```

### 5. Save Outputs

```bash
# Save outputs to a file for later use
terraform output -json > ../../outputs.json

# View outputs
cat ../../outputs.json | jq '.'
```

## Configure and Run the Agent

### 1. Update Agent Configuration

```bash
# Navigate to agent directory
cd ../../../agent/strands-agent

# Create configuration from Terraform outputs
cat > config.json << EOF
{
  "agent_id": "$(jq -r '.agent_id.value' ../../outputs.json)",
  "agent_arn": "$(jq -r '.agent_arn.value' ../../outputs.json)",
  "documents_bucket": "$(jq -r '.documents_bucket_name.value' ../../outputs.json)",
  "vectors_bucket": "$(jq -r '.vectors_bucket_name.value' ../../outputs.json)",
  "embedding_model": "${BEDROCK_EMBEDDING_MODEL}",
  "llm_model": "${BEDROCK_LLM_MODEL}",
  "chunk_size": ${CHUNK_SIZE},
  "chunk_overlap": ${CHUNK_OVERLAP},
  "top_k_results": ${TOP_K_RESULTS}
}
EOF
```

### 2. Test Agent Locally (Optional)

```bash
# Run agent tests
python -m pytest tests/ -v

# Expected output:
# tests/test_s3_tool.py::test_upload_document PASSED
# tests/test_embeddings_tool.py::test_generate_embeddings PASSED
# tests/test_search_tool.py::test_vector_search PASSED
```

### 3. Deploy Agent to AgentCore

```bash
# Package agent code
zip -r agent.zip src/ config.json requirements.txt

# Deploy to AgentCore (using AWS CLI or agentcore CLI)
# Note: This step will be automated in CI/CD
# For now, manual deployment instructions:

# Upload to S3
aws s3 cp agent.zip s3://$(jq -r '.documents_bucket_name.value' ../../outputs.json)/agent/

# Update agent configuration
aws bedrock-agent update-agent \
  --agent-id $(jq -r '.agent_id.value' ../../outputs.json) \
  --agent-name agentic-rag-demo-agent \
  --region ${AWS_REGION}
```

## Run the Streamlit UI

### 1. Configure Streamlit App

```bash
# Navigate to UI directory
cd ../../ui/streamlit-app

# Create Streamlit configuration
mkdir -p .streamlit
cat > .streamlit/config.toml << EOF
[theme]
primaryColor = "#FF4B4B"
backgroundColor = "#FFFFFF"
secondaryBackgroundColor = "#F0F2F6"
textColor = "#262730"
font = "sans serif"

[server]
port = 8501
enableCORS = false
enableXsrfProtection = true
EOF
```

### 2. Create Environment Configuration

```bash
# Create .env file for Streamlit
cat > .env << EOF
AWS_REGION=${AWS_REGION}
AGENT_ID=$(jq -r '.agent_id.value' ../../outputs.json)
AGENT_ARN=$(jq -r '.agent_arn.value' ../../outputs.json)
DOCUMENTS_BUCKET=$(jq -r '.documents_bucket_name.value' ../../outputs.json)
EOF
```

### 3. Run Streamlit Locally

```bash
# Ensure virtual environment is activated
source ../../venv/bin/activate

# Run Streamlit
streamlit run app.py

# Expected output:
#   You can now view your Streamlit app in your browser.
#
#   Local URL: http://localhost:8501
#   Network URL: http://192.168.1.100:8501
```

### 4. Access the UI

Open your browser and navigate to: `http://localhost:8501`

You should see the Recall interface with:
- Document upload widget
- Chat interface
- Message history

## Verification and Testing

### 1. Test Document Upload

**Via Streamlit UI:**
1. Open `http://localhost:8501`
2. Click "Upload Document" in the sidebar
3. Select a test file (PDF, TXT, MD, DOCX)
4. In the chat, type: "Please upload this document"
5. Wait for confirmation message

**Verify in AWS Console:**
```bash
# Check S3 for uploaded document
aws s3 ls s3://$(jq -r '.documents_bucket_name.value' outputs.json)/documents/ --recursive

# Expected output:
# 2026-02-05 10:30:00   1048576 documents/abc-123-def/original.pdf
# 2026-02-05 10:30:01      512 documents/abc-123-def/metadata.json
```

### 2. Test Query Functionality

**Via Streamlit UI:**
1. In the chat, type: "What does the document say about [topic]?"
2. Wait for agent response
3. Verify response includes:
   - Relevant answer
   - Source document reference
   - Confidence/similarity score

**Check CloudWatch Logs:**
```bash
# View agent logs
aws logs tail /aws/agentcore/agentic-rag-demo-agent --follow

# Look for:
# - Query embedding generation
# - Vector search execution
# - Retrieved chunks
# - LLM response generation
```

### 3. End-to-End Test Script

```bash
# Run automated test
cd ../../tests
python test_e2e.py

# Expected output:
# ✓ Agent connection successful
# ✓ Document upload successful
# ✓ Embedding generation successful
# ✓ Vector search successful
# ✓ Query response successful
# ✓ All tests passed!
```

### 4. Verify Cost Tracking

```bash
# Check cost allocation tags
aws ce get-cost-and-usage \
  --time-period Start=2026-02-01,End=2026-02-06 \
  --granularity DAILY \
  --metrics BlendedCost \
  --filter file://cost-filter.json

# cost-filter.json:
# {
#   "Tags": {
#     "Key": "Project",
#     "Values": ["agentic-rag-demo"]
#   }
# }
```

## Troubleshooting

### Common Issues

#### Issue 1: Terraform Backend Initialization Fails

**Error:**
```
Error: Failed to get existing workspaces: S3 bucket does not exist
```

**Solution:**
```bash
# Ensure backend bucket exists
cd terraform/backend
terraform init
terraform apply

# Then retry environment initialization
cd ../environments/dev
terraform init
```

#### Issue 2: Bedrock Model Access Denied

**Error:**
```
AccessDeniedException: You don't have access to the model with the specified model ID.
```

**Solution:**
1. Go to [Bedrock Console](https://console.aws.amazon.com/bedrock)
2. Enable model access for Titan Embeddings and Claude 3.5 Sonnet
3. Wait for approval (check email)
4. Retry terraform apply

#### Issue 3: AgentCore Deployment Fails

**Error:**
```
Error creating Bedrock Agent: ValidationException: Agent role is missing required permissions
```

**Solution:**
```bash
# Check IAM role trust policy
aws iam get-role --role-name agentic-rag-demo-agent-role-dev

# Ensure trust policy includes:
# - bedrock.amazonaws.com
# - agentcore.amazonaws.com

# Reapply Terraform
terraform apply -target=aws_iam_role.agent_role
```

#### Issue 4: Streamlit Can't Connect to Agent

**Error:**
```
ClientError: An error occurred (ResourceNotFoundException) when calling the InvokeAgent operation
```

**Solution:**
```bash
# Verify agent ID in .env
cat ui/streamlit-app/.env

# Check agent status
aws bedrock-agent get-agent \
  --agent-id <your-agent-id> \
  --query 'agent.{Status:agentStatus,Name:agentName}'

# Ensure status is "READY" or "AVAILABLE"
```

#### Issue 5: Python Import Errors

**Error:**
```
ModuleNotFoundError: No module named 'strands'
```

**Solution:**
```bash
# Reinstall dependencies
pip install --upgrade pip
pip install -r requirements.txt

# Verify installation
pip show strands-agent-framework
```

### Getting Help

If you encounter issues not covered here:

1. **Check CloudWatch Logs**: Most errors are logged to CloudWatch
   ```bash
   aws logs tail /aws/agentcore/<agent-name> --follow
   ```

2. **Review Terraform Output**: Look for error messages in terraform apply
   ```bash
   terraform plan -detailed-exitcode
   ```

3. **AWS Service Health**: Check for service outages
   - [AWS Service Health Dashboard](https://status.aws.amazon.com/)

4. **Open an Issue**: Report bugs or request help
   - [GitHub Issues](https://github.com/yourusername/agentic-rag-demo/issues)

### Debug Mode

Enable verbose logging for troubleshooting:

```bash
# Terraform debug mode
export TF_LOG=DEBUG
terraform apply

# AWS CLI debug mode
aws bedrock-agent get-agent --agent-id <id> --debug

# Streamlit debug mode
streamlit run app.py --logger.level=debug
```

## Next Steps

Once setup is complete:

1. ✅ Review [ARCHITECTURE.md](ARCHITECTURE.md) for system details
2. ✅ Review [DEPLOYMENT.md](DEPLOYMENT.md) for CI/CD setup
3. ✅ Upload test documents and experiment with queries
4. ✅ Monitor costs in AWS Cost Explorer
5. ✅ Customize agent prompts and tools as needed

## Clean Up (Optional)

To avoid ongoing AWS charges, destroy resources when done:

```bash
# Destroy dev environment
cd terraform/environments/dev
terraform destroy

# Confirm by typing 'yes'

# Optionally, destroy backend (careful!)
cd ../../backend
terraform destroy
```

---

**Document Version**: 1.0
**Last Updated**: 2026-02-05
**Support**: [GitHub Issues](https://github.com/yourusername/agentic-rag-demo/issues)
