"""Configuration management for the Agentic RAG agent.

Loads settings from multiple sources with the following priority
(later sources override earlier ones):

  1. .env file       — local development convenience (never committed)
  2. SSM Parameter Store — deployed environments (written by Terraform)
  3. Environment variables — explicit overrides, CI, testing

Set SSM_PARAMETER_PREFIX (e.g. /agentic-rag-demo/dev) to enable SSM loading.
"""

import logging
import os
from dataclasses import dataclass
from pathlib import Path

logger = logging.getLogger(__name__)

# Maps UPPERCASE env var names (used in .env files and shell) to lowercase
# config keys (used internally and in SSM parameter names).
_ENV_VAR_MAP: dict[str, str] = {
    "AWS_REGION": "aws_region",
    "ENVIRONMENT": "environment",
    "DOCUMENTS_BUCKET": "documents_bucket",
    "VECTORS_BUCKET": "vectors_bucket",
    "VECTOR_INDEX": "vector_index",
    "EMBEDDING_MODEL": "embedding_model",
    "LLM_MODEL": "llm_model",
    "VECTOR_DIMENSIONS": "vector_dimensions",
    "AGENT_MODE": "agent_mode",
    "AGENTCORE_RUNTIME_ARN": "agentcore_runtime_arn",
}


@dataclass(frozen=True)
class Settings:
    """Application settings. Constructed by get_settings(), not directly."""

    # AWS
    aws_region: str = "us-east-1"
    environment: str = "dev"

    # S3 Documents
    documents_bucket: str = ""

    # S3 Vectors
    vectors_bucket: str = ""
    vector_index: str = ""

    # Bedrock Models
    embedding_model_id: str = "amazon.titan-embed-text-v2:0"
    llm_model_id: str = "us.anthropic.claude-3-5-sonnet-20241022-v2:0"

    # Vector Configuration
    vector_dimensions: int = 1024

    # Chunking Configuration
    chunk_size: int = 4000
    chunk_overlap: int = 800

    # Search Configuration
    default_top_k: int = 5
    min_score_threshold: float = 0.3

    # AgentCore Runtime (for remote invocation from Streamlit)
    agent_mode: str = "local"
    agentcore_runtime_arn: str = ""


def _load_from_env_file() -> dict[str, str]:
    """Load config from a .env file in the current working directory."""
    env_path = Path.cwd() / ".env"
    if not env_path.is_file():
        return {}

    try:
        from dotenv import dotenv_values
    except ImportError:
        logger.debug("python-dotenv not installed, skipping .env file")
        return {}

    raw = dotenv_values(env_path)
    config: dict[str, str] = {}
    for env_key, value in raw.items():
        if value and env_key in _ENV_VAR_MAP:
            config[_ENV_VAR_MAP[env_key]] = value
    if config:
        logger.info("Loaded %d settings from .env file", len(config))
    return config


def _load_from_ssm(prefix: str) -> dict[str, str]:
    """Load all parameters under an SSM path prefix.

    Parameters are stored by Terraform at paths like:
        /agentic-rag-demo/dev/documents_bucket

    The last path segment becomes the config key name.
    """
    import boto3

    region = os.environ.get("AWS_REGION", "us-east-1")
    client = boto3.client("ssm", region_name=region)

    config: dict[str, str] = {}
    paginator = client.get_paginator("get_parameters_by_path")
    for page in paginator.paginate(
        Path=prefix,
        Recursive=False,
        WithDecryption=True,
    ):
        for param in page["Parameters"]:
            key = param["Name"].rsplit("/", 1)[-1]
            config[key] = param["Value"]

    logger.info("Loaded %d settings from SSM prefix '%s'", len(config), prefix)
    return config


def _load_from_env_vars() -> dict[str, str]:
    """Load config from environment variables."""
    config: dict[str, str] = {}
    for env_key, config_key in _ENV_VAR_MAP.items():
        value = os.environ.get(env_key)
        if value:
            config[config_key] = value
    return config


def _load_config() -> dict[str, str]:
    """Merge configuration from all sources."""
    config: dict[str, str] = {}

    # 1. .env file (lowest priority)
    config.update(_load_from_env_file())

    # 2. SSM Parameter Store (if prefix is set)
    ssm_prefix = os.environ.get("SSM_PARAMETER_PREFIX", "")
    if ssm_prefix:
        try:
            config.update(_load_from_ssm(ssm_prefix))
        except Exception as e:
            logger.warning("Failed to load from SSM (%s), falling back to other sources", e)

    # 3. Environment variables (highest priority)
    config.update(_load_from_env_vars())

    return config


def _validate_required(settings: Settings) -> None:
    """Raise if required infrastructure settings are missing."""
    missing = []
    if not settings.documents_bucket:
        missing.append("DOCUMENTS_BUCKET")
    if not settings.vectors_bucket:
        missing.append("VECTORS_BUCKET")
    if not settings.vector_index:
        missing.append("VECTOR_INDEX")

    if missing:
        raise ValueError(
            f"Missing required configuration: {', '.join(missing)}. "
            f"Set them via .env file, SSM_PARAMETER_PREFIX, or environment variables."
        )


_settings: Settings | None = None


def get_settings() -> Settings:
    """Get cached application settings.

    On first call, loads config from .env / SSM / env vars and validates.
    """
    global _settings
    if _settings is None:
        config = _load_config()
        _settings = Settings(
            aws_region=config.get("aws_region", "us-east-1"),
            environment=config.get("environment", "dev"),
            documents_bucket=config.get("documents_bucket", ""),
            vectors_bucket=config.get("vectors_bucket", ""),
            vector_index=config.get("vector_index", ""),
            embedding_model_id=config.get("embedding_model", "amazon.titan-embed-text-v2:0"),
            llm_model_id=config.get(
                "llm_model", "us.anthropic.claude-3-5-sonnet-20241022-v2:0"
            ),
            vector_dimensions=int(config.get("vector_dimensions", "1024")),
            agent_mode=config.get("agent_mode", "local"),
            agentcore_runtime_arn=config.get("agentcore_runtime_arn", ""),
        )
        _validate_required(_settings)
    return _settings


def reset_settings() -> None:
    """Reset cached settings. Useful for testing."""
    global _settings
    _settings = None
