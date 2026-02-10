"""Bedrock Embeddings Client - generates vector embeddings using Amazon Titan.

Provides both a Strands @tool for direct agent use and internal helper
functions used by the document_manager and vector_search tools.
"""

import json
import logging
import random
import time
from functools import cache

import boto3
from botocore.exceptions import ClientError
from strands import tool

from agentic_rag.config import get_settings

logger = logging.getLogger(__name__)

MAX_RETRIES = 5
EMBEDDING_INPUT_LIMIT_CHARS = 30_000  # Conservative limit (~7.5K tokens)


@cache
def _get_bedrock_client() -> boto3.client:
    """Get a cached Bedrock Runtime client."""
    settings = get_settings()
    return boto3.client("bedrock-runtime", region_name=settings.aws_region)


def generate_embedding_vector(text: str) -> list[float]:
    """Generate a single embedding vector from text.

    Uses Amazon Titan Embeddings v2 via Bedrock with exponential backoff
    retry for throttling. Truncates input if it exceeds the model's limit.

    Args:
        text: The text to embed.

    Returns:
        A list of floats representing the embedding vector.

    Raises:
        ClientError: If the Bedrock API call fails after retries.
    """
    settings = get_settings()
    client = _get_bedrock_client()

    if len(text) > EMBEDDING_INPUT_LIMIT_CHARS:
        logger.warning(
            "Text truncated from %d to %d chars for embedding",
            len(text),
            EMBEDDING_INPUT_LIMIT_CHARS,
        )
        text = text[:EMBEDDING_INPUT_LIMIT_CHARS]

    body = json.dumps({
        "inputText": text,
        "dimensions": settings.vector_dimensions,
        "normalize": True,
    })

    for attempt in range(MAX_RETRIES + 1):
        try:
            response = client.invoke_model(
                modelId=settings.embedding_model_id,
                body=body,
            )
            result = json.loads(response["body"].read())
            return result["embedding"]
        except ClientError as e:
            error_code = e.response["Error"]["Code"]
            if error_code in ("ThrottlingException", "TooManyRequestsException") and attempt < MAX_RETRIES:
                delay = min(2**attempt + random.uniform(0, 1), 30)
                logger.warning("Throttled on embedding attempt %d, retrying in %.1fs", attempt + 1, delay)
                time.sleep(delay)
            else:
                raise


def generate_embeddings_batch(texts: list[str]) -> list[list[float]]:
    """Generate embeddings for a batch of texts.

    Processes texts sequentially with retry logic. For large batches,
    includes brief delays between requests to avoid rate limits.

    Args:
        texts: List of text strings to embed.

    Returns:
        List of embedding vectors, one per input text.
    """
    embeddings = []
    for i, text in enumerate(texts):
        embedding = generate_embedding_vector(text)
        embeddings.append(embedding)

        if i > 0 and i % 20 == 0:
            logger.info("Generated embeddings for %d/%d chunks", i, len(texts))
            time.sleep(0.1)

    logger.info("Generated %d embeddings", len(embeddings))
    return embeddings


@tool
def generate_embeddings(text: str) -> str:
    """Generate a vector embedding for the given text using Amazon Titan Embeddings.

    Converts text into a numerical vector representation that captures semantic
    meaning. Useful for understanding how text is represented in the vector space.

    Args:
        text: The text to generate an embedding for.
    """
    try:
        settings = get_settings()
        embedding = generate_embedding_vector(text)
        return (
            f"Generated {settings.vector_dimensions}-dimensional embedding for "
            f"{len(text)} characters of text.\n"
            f"Model: {settings.embedding_model_id}\n"
            f"First 5 values: {embedding[:5]}\n"
            f"Vector norm: {sum(v**2 for v in embedding) ** 0.5:.4f}"
        )
    except Exception as e:
        logger.exception("Failed to generate embedding")
        return f"Error generating embedding: {e}"
