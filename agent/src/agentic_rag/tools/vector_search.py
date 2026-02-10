"""S3 Vectors Search Client - vector storage and similarity search.

Handles all interactions with Amazon S3 Vectors for storing document
chunk embeddings and performing k-NN similarity searches.
"""

import logging
from functools import cache

import boto3
from botocore.exceptions import ClientError
from strands import tool

from agentic_rag.config import get_settings
from agentic_rag.tools.embeddings_client import generate_embedding_vector

logger = logging.getLogger(__name__)

VECTORS_PER_BATCH = 500  # S3 Vectors API limit
# S3 Vectors metadata has a size limit per vector.  Truncate chunk text
# stored in metadata to stay well within the limit.  Full chunk texts
# are stored separately in S3 (see document_manager.py).
METADATA_TEXT_MAX_CHARS = 500


@cache
def _get_s3vectors_client() -> boto3.client:
    """Get a cached S3 Vectors client."""
    settings = get_settings()
    return boto3.client("s3vectors", region_name=settings.aws_region)


def store_document_vectors(
    document_id: str,
    document_filename: str,
    chunk_texts: list[str],
    embeddings: list[list[float]],
) -> int:
    """Store chunk embeddings in S3 Vectors.

    Batches vectors into groups of 500 (API limit) and stores them
    with metadata for later retrieval and filtering.

    Args:
        document_id: Unique document identifier.
        document_filename: Original filename for metadata.
        chunk_texts: List of chunk text strings.
        embeddings: Corresponding embedding vectors.

    Returns:
        Number of vectors successfully stored.

    Raises:
        ClientError: If the S3 Vectors API call fails.
    """
    settings = get_settings()
    client = _get_s3vectors_client()

    vectors = []
    for i, (text, embedding) in enumerate(zip(chunk_texts, embeddings)):
        # Truncate chunk text for metadata to stay within S3 Vectors size limits.
        # Full text is stored in S3 alongside the document (chunks.json).
        truncated = text[:METADATA_TEXT_MAX_CHARS]
        if len(text) > METADATA_TEXT_MAX_CHARS:
            truncated += "..."
        vectors.append({
            "key": f"{document_id}#{i}",
            "data": {"float32": embedding},
            "metadata": {
                "document_id": document_id,
                "document_filename": document_filename,
                "chunk_index": i,
                "chunk_text": truncated,
            },
        })

    stored_count = 0
    for batch_start in range(0, len(vectors), VECTORS_PER_BATCH):
        batch = vectors[batch_start : batch_start + VECTORS_PER_BATCH]
        client.put_vectors(
            vectorBucketName=settings.vectors_bucket,
            indexName=settings.vector_index,
            vectors=batch,
        )
        stored_count += len(batch)
        logger.info(
            "Stored vectors %d-%d of %d for document %s",
            batch_start,
            batch_start + len(batch) - 1,
            len(vectors),
            document_id,
        )

    return stored_count


def delete_document_vectors(document_id: str, chunk_count: int) -> int:
    """Delete all vectors associated with a document.

    Uses the predictable key pattern '{document_id}#{chunk_index}'
    to generate all vector keys for deletion.

    Args:
        document_id: The document whose vectors should be deleted.
        chunk_count: Number of chunks (vectors) to delete.

    Returns:
        Number of vectors deleted.
    """
    settings = get_settings()
    client = _get_s3vectors_client()

    keys = [f"{document_id}#{i}" for i in range(chunk_count)]

    deleted_count = 0
    for batch_start in range(0, len(keys), VECTORS_PER_BATCH):
        batch = keys[batch_start : batch_start + VECTORS_PER_BATCH]
        try:
            client.delete_vectors(
                vectorBucketName=settings.vectors_bucket,
                indexName=settings.vector_index,
                keys=batch,
            )
            deleted_count += len(batch)
        except ClientError as e:
            logger.warning("Error deleting vector batch starting at %d: %s", batch_start, e)

    logger.info("Deleted %d vectors for document %s", deleted_count, document_id)
    return deleted_count


@tool
def search_knowledge_base(query: str, top_k: int = 5) -> str:
    """Search the knowledge base for document passages relevant to a query.

    Converts the query into an embedding vector and performs a similarity search
    against all indexed document chunks. Returns the most relevant passages along
    with their source documents and relevance scores.

    Args:
        query: The natural language question or search query.
        top_k: Maximum number of results to return. Defaults to 5.
    """
    settings = get_settings()
    client = _get_s3vectors_client()

    try:
        query_embedding = generate_embedding_vector(query)
    except Exception as e:
        logger.exception("Failed to generate query embedding")
        return f"Error generating query embedding: {e}"

    try:
        response = client.query_vectors(
            vectorBucketName=settings.vectors_bucket,
            indexName=settings.vector_index,
            queryVector={"float32": query_embedding},
            topK=top_k,
            returnMetadata=True,
        )
    except ClientError as e:
        error_code = e.response["Error"]["Code"]
        if error_code == "ResourceNotFoundException":
            return "The knowledge base is empty. No documents have been uploaded yet."
        logger.exception("S3 Vectors query failed")
        return f"Error searching knowledge base: {e}"

    vectors = response.get("vectors", [])
    if not vectors:
        return (
            "No relevant results found for your query. "
            "Try rephrasing your question or upload more documents."
        )

    results = []
    for i, vector in enumerate(vectors, 1):
        metadata = vector.get("metadata", {})
        distance = vector.get("distance", 0)
        # S3 Vectors returns distance (lower = more similar for cosine).
        # Convert to a 0-1 similarity score for readability.
        similarity = max(0, 1 - distance)

        chunk_text = metadata.get("chunk_text", "N/A")
        filename = metadata.get("document_filename", "Unknown")
        chunk_index = metadata.get("chunk_index", "?")

        quality = "High" if similarity >= 0.7 else "Medium" if similarity >= 0.5 else "Low"

        results.append(
            f"--- Result {i} [{quality} relevance: {similarity:.2f}] ---\n"
            f"Source: {filename} (chunk {chunk_index})\n"
            f"Content:\n{chunk_text}\n"
        )

    header = f"Found {len(results)} relevant passages for: \"{query}\"\n\n"
    return header + "\n".join(results)
