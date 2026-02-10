# Recall

**Agentic document management and intelligent search.**

A bidirectional RAG (Retrieval Augmented Generation) system built on AWS. Users upload documents, query them with natural language, and manage their knowledge base through a conversational AI agent.

Unlike traditional read-only RAG systems, this agent can both retrieve information **and** accept new documents, creating a living, adaptive knowledge base.

## Architecture

```
Streamlit UI (local)
      │
      ├── Local mode ──> Strands Agent (in-process)
      │                        │
      └── AgentCore mode ──> AgentCore Runtime (AWS)
                                   │
                    ┌──────────────┼──────────────┐
                    │              │              │
              Amazon S3      Amazon Bedrock   S3 Vectors
            (documents)    (Claude + Titan)  (embeddings)
```

**Document upload**: Streamlit uploads the file to S3, then tells the agent to process it. The agent extracts text, chunks it, generates embeddings via Bedrock Titan, and stores vectors in S3 Vectors.

**Query**: The agent embeds the question, performs vector similarity search, and synthesizes an answer with source attribution using Claude.

## Technology Stack

| Layer | Technology |
|-------|-----------|
| Agent framework | [Strands Agents](https://github.com/strands-agents/strands-agents-python) with Bedrock |
| LLM | Claude 3.5 Sonnet via Amazon Bedrock |
| Embeddings | Amazon Titan Embed Text v2 (1024 dimensions) |
| Document storage | Amazon S3 |
| Vector storage | Amazon S3 Vectors |
| Agent hosting | Amazon Bedrock AgentCore Runtime (optional) |
| UI | Streamlit |
| Infrastructure | Terraform (modular, multi-environment) |
| CI/CD | GitHub Actions |
| Configuration | SSM Parameter Store + `.env` fallback |

## Project Structure

```
agentic-rag-demo/
├── agent/                          # Python application
│   ├── src/agentic_rag/            # Core package
│   │   ├── tools/                  # Strands @tool definitions
│   │   │   ├── document_manager.py # Upload, list, delete documents
│   │   │   ├── embeddings_client.py# Bedrock Titan embeddings
│   │   │   └── vector_search.py    # S3 Vectors similarity search
│   │   ├── agent.py                # Agent factory (create_agent)
│   │   ├── config.py               # Settings loader (SSM / .env / env vars)
│   │   └── text_processing.py      # Text extraction and chunking
│   ├── app.py                      # Streamlit UI (local + agentcore modes)
│   ├── main.py                     # AgentCore Runtime entry point
│   ├── pyproject.toml              # Python project config & dependencies
│   ├── requirements.txt            # Pinned deps for AgentCore container
│   └── .env.example                # Local config template
├── terraform/
│   ├── backend/                    # Remote state (S3 + DynamoDB)
│   ├── environments/
│   │   ├── dev/                    # Dev environment config
│   │   └── prod/                   # Prod environment config
│   ├── modules/                    # Reusable modules
│   │   ├── bedrock-agent/          # Bedrock Agent resource
│   │   ├── cloudwatch-logs/        # Logging & monitoring
│   │   ├── iam-roles/              # Least-privilege IAM
│   │   ├── s3-storage/             # Document bucket
│   │   └── s3-vectors/             # Vector bucket & index
│   └── scripts/
│       └── generate-backend-configs.sh
├── docs/                           # Architecture & deployment docs
└── .github/workflows/              # CI/CD pipelines
```

## Prerequisites

- **AWS Account** with permissions to create S3, Bedrock, SSM, IAM, CloudWatch, Lambda, and S3 Vectors resources
- **AWS CLI** v2, configured with credentials (`aws configure` or environment variables)
- **Terraform** >= 1.5.0
- **Python** >= 3.11
- **Git**

Make sure the Bedrock models are enabled in your account's region:
- `amazon.titan-embed-text-v2:0`
- `us.anthropic.claude-3-5-sonnet-20241022-v2:0`

You can enable them in the [Bedrock Model Access](https://console.aws.amazon.com/bedrock/home#/modelaccess) console page.

---

## Getting Started

### Step 1: Clone the repository

```bash
git clone https://github.com/yourusername/agentic-rag-demo.git
cd agentic-rag-demo
```

### Step 2: Deploy the Terraform backend

The backend stores Terraform state remotely in S3 with DynamoDB locking. This only needs to be done once.

```bash
cd terraform/backend
terraform init
terraform apply
```

Review the plan and type `yes` when prompted. Note the outputs -- you'll need the bucket name and lock table name.

### Step 3: Generate backend configuration files

From the repo root:

```bash
cd terraform/scripts
chmod +x generate-backend-configs.sh
./generate-backend-configs.sh
```

This reads the backend outputs and creates `backend.hcl` files for each environment.

### Step 4: Deploy the dev environment

```bash
cd ../environments/dev

# Copy and customize the tfvars file
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars if you want to change region, models, etc.

terraform init -backend-config=backend.hcl
terraform apply
```

This creates all AWS resources: S3 buckets, S3 Vectors index, IAM roles, CloudWatch logs, Bedrock agent, and SSM parameters.

After a successful apply, review the outputs:

```bash
# See all configuration values the agent needs
terraform output -json agent_config

# See the SSM prefix for the agent
terraform output ssm_parameter_prefix
# => /agentic-rag-demo/dev
```

Terraform automatically writes all infrastructure values (bucket names, index names, model IDs, etc.) to SSM Parameter Store under this prefix. The agent reads them at startup -- no manual copying required.

### Step 5: Set up the Python environment

```bash
cd ../../../agent

python -m venv .venv
source .venv/bin/activate    # On Windows: .venv\Scripts\activate

pip install -e ".[dev]"
```

### Step 6: Configure local development

For local development, create a `.env` file so the agent can find your infrastructure:

```bash
cp .env.example .env
```

Then fill in the three required values from the Terraform outputs:

```bash
# Get the values from Terraform
cd ../terraform/environments/dev
terraform output -json agent_config
```

Copy the `documents_bucket`, `vectors_bucket`, and `vector_index` values into your `.env` file.

Alternatively, if your AWS credentials have SSM access, you can skip the `.env` file entirely and set a single environment variable:

```bash
export SSM_PARAMETER_PREFIX=/agentic-rag-demo/dev
```

The agent will load all configuration from SSM automatically.

**Configuration priority** (later sources override earlier ones):
1. `.env` file (lowest)
2. SSM Parameter Store
3. Environment variables (highest)

### Step 7: Run the Streamlit UI

```bash
cd agent  # if not already there
streamlit run app.py
```

The app opens at `http://localhost:8501`. By default it runs in **local mode** -- the Strands Agent runs in-process alongside Streamlit.

You can now:
- Upload PDF, DOCX, TXT, or Markdown files using the sidebar
- Ask questions about uploaded documents in the chat
- List or delete documents from the knowledge base

---

## AgentCore Deployment (Optional)

To run the agent remotely on AgentCore Runtime instead of in-process:

### Deploy to AgentCore

```bash
cd agent
agentcore deploy
```

This builds a container from `requirements.txt` and `main.py`, and deploys it to AgentCore Runtime. Note the Runtime ARN from the output.

### Configure Streamlit to use AgentCore

Add these to your `.env` file (or set as environment variables):

```
AGENT_MODE=agentcore
AGENTCORE_RUNTIME_ARN=arn:aws:bedrock-agentcore:us-east-1:123456789012:runtime/your-runtime-id
```

Then restart Streamlit. The sidebar will show **Agent mode: AgentCore** to confirm it's calling the remote agent.

---

## GitHub Actions Deployment

The repository includes workflows for automated Terraform deployment:

```bash
# 1. Configure GitHub Secrets (one-time)
# See .github/GITHUB_ACTIONS_SETUP.md

# 2. Push to trigger deployment
git push origin main
```

See [.github/GITHUB_ACTIONS_SETUP.md](.github/GITHUB_ACTIONS_SETUP.md) for the full setup guide.

## Documentation

- [Architecture Guide](docs/ARCHITECTURE.md) -- design decisions, data flow diagrams, security model
- [Setup Guide](docs/SETUP.md) -- detailed AWS account setup
- [Deployment Guide](docs/DEPLOYMENT.md) -- CI/CD pipeline and production deployment

## Cost Estimate (Dev)

| Service | Estimated Monthly Cost |
|---------|----------------------|
| S3 Storage (10 GB) | ~$0.23 |
| S3 Vectors (50 queries) | ~$2.50 |
| Bedrock Embeddings (100K tokens) | ~$0.10 |
| Bedrock LLM (500K tokens) | ~$7.50 |
| AgentCore (50 invocations) | ~$2.50 |
| CloudWatch Logs (1 GB) | ~$0.50 |
| **Total** | **~$13/month** |

Production costs scale with usage. See [docs/DEPLOYMENT.md](docs/DEPLOYMENT.md) for optimization strategies.

## License

MIT License -- See LICENSE file for details.

---

**Note**: This is a demonstration project. For production use, add authentication, input validation, rate limiting, and comprehensive monitoring.
