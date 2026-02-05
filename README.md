# Agentic RAG Demo

A production-ready bidirectional RAG (Retrieval Augmented Generation) system built on AWS that enables intelligent document management and retrieval through an AI agent.

## Overview

This project demonstrates a complete RAG architecture where users can:
- **Upload documents** through a conversational interface
- **Query knowledge** with natural language
- **Dynamically manage** their document knowledge base

Unlike traditional RAG systems that are read-only, this bidirectional approach allows the agent to both retrieve information AND accept new documents, creating a living, adaptive knowledge base.

## Key Features

- **Intelligent Document Processing**: Automatic chunking, embedding, and vector storage
- **Natural Language Interface**: Chat-based interaction powered by Streamlit UI
- **AWS-Native Architecture**: Leverages S3, S3 Vectors, and Bedrock for scalability
- **Infrastructure as Code**: Complete Terraform deployment with dev/prod environments
- **CI/CD Pipeline**: Automated deployment through GitHub Actions
- **Cost-Optimized**: On-demand pricing with no idle infrastructure costs

## Architecture

The system follows a modern serverless architecture:

1. **Document Upload Flow**:
   - User uploads document via Streamlit UI
   - Agent stores document in S3
   - Document is chunked using recursive text splitting
   - Chunks are embedded using Bedrock embeddings model
   - Vectors are stored in S3 Vectors for fast retrieval

2. **Query Flow**:
   - User asks a question via Streamlit UI
   - Question is embedded using Bedrock
   - Vector similarity search in S3 Vectors finds relevant chunks
   - Agent synthesizes response with source attribution
   - Response includes relevant document references

## Technology Stack

### AWS Services
- **S3**: Document storage with intelligent tiering
- **S3 Vectors**: Vector similarity search datastore
- **Bedrock**: LLM and embeddings (Amazon Titan)
- **AgentCore**: Serverless agent runtime and orchestration
- **CloudWatch**: Logging and monitoring

### Frameworks & Tools
- **Strands Agents**: Agent framework for building agentic workflows
- **Streamlit**: Interactive web UI
- **Terraform**: Infrastructure as Code
- **GitHub Actions**: CI/CD automation

## Project Structure

```
agentic-rag-demo/
├── docs/               # Comprehensive documentation
│   ├── ARCHITECTURE.md # Architectural decisions and diagrams
│   ├── SETUP.md        # Local setup instructions
│   └── DEPLOYMENT.md   # Deployment guide
├── terraform/          # Infrastructure as Code
│   ├── environments/   # Environment-specific configs
│   ├── modules/        # Reusable Terraform modules
│   └── backend/        # Terraform state backend
├── agent/              # Strands agent implementation
│   └── strands-agent/  # Agent code and tools
├── ui/                 # User interface
│   └── streamlit-app/  # Streamlit application
└── .github/            # CI/CD workflows
    └── workflows/      # GitHub Actions
```

## Quick Start

### Prerequisites
- AWS Account with appropriate permissions
- Terraform >= 1.5.0
- AWS CLI configured
- Python >= 3.11
- Git

### Setup

```bash
# Clone the repository
git clone https://github.com/yourusername/agentic-rag-demo.git
cd agentic-rag-demo

# 1. Set up Terraform backend
cd terraform/backend
terraform init
terraform apply

# 2. Generate backend configuration files
cd ../scripts
./generate-backend-configs.sh

# 3. Deploy development environment
cd ../environments/dev
terraform init -backend-config=backend.hcl
terraform apply

# 4. Run the Streamlit UI locally
cd ../../../ui/streamlit-app
pip install -r requirements.txt
streamlit run app.py
```

For detailed setup instructions, see [docs/SETUP.md](docs/SETUP.md).

### GitHub Actions Deployment (Recommended)

Automatically deploy infrastructure when you push to GitHub:

```bash
# 1. Set up GitHub Secrets (one-time)
# See .github/GITHUB_ACTIONS_SETUP.md for detailed instructions

# 2. Push to GitHub
git add .
git commit -m "Initial commit"
git push origin main

# 3. GitHub Actions will automatically deploy!
```

**Benefits**:
- ✅ FREE for public repos (unlimited minutes)
- ✅ FREE 2,000 minutes/month for private repos
- ✅ Automatic deployment on push
- ✅ PR preview plans
- ✅ Production environment protection

See [.github/GITHUB_ACTIONS_SETUP.md](.github/GITHUB_ACTIONS_SETUP.md) for complete setup guide.

## Documentation

- **[Architecture Guide](docs/ARCHITECTURE.md)**: Detailed architecture, design decisions, and data flow
- **[Setup Guide](docs/SETUP.md)**: Step-by-step setup for your AWS account
- **[Deployment Guide](docs/DEPLOYMENT.md)**: CI/CD pipeline and deployment workflows

## Security & Best Practices

This project demonstrates production-ready practices:
- ✅ No hardcoded ARNs or account IDs
- ✅ Least privilege IAM policies
- ✅ Encrypted data at rest (S3 SSE)
- ✅ Modular, reusable Terraform code
- ✅ Environment isolation (dev/prod)
- ✅ Comprehensive logging and monitoring
- ✅ Cost optimization through serverless architecture

## Cost Estimation

Estimated monthly costs for light usage (dev environment):
- S3 Storage: ~$0.50 (10GB)
- S3 Vectors: Pay per query (~$5-10)
- Bedrock: Pay per token (~$10-20)
- AgentCore: Pay per execution (~$5-10)

**Total: ~$20-40/month** for development workloads

Production costs scale with usage. See [docs/DEPLOYMENT.md](docs/DEPLOYMENT.md) for optimization strategies.

## Contributing

Contributions welcome! This is a demonstration project showcasing AWS serverless architecture patterns and modern RAG implementations.

## License

MIT License - See LICENSE file for details

## Acknowledgments

Built with:
- AWS IAM Terraform Modules
- Amazon Bedrock Agents
- Strands Agent Framework
- Streamlit

---

**Note**: This is a demonstration project. For production use, implement additional security controls including authentication, input validation, rate limiting, and comprehensive monitoring.
