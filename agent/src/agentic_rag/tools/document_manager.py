"""S3 Document Manager - document upload, listing, and deletion.

Handles the full document processing pipeline: upload to S3, text
extraction, chunking, embedding generation, and vector storage.
Also provides listing and deletion with vector cleanup.
"""

import json
import logging
import uuid
from datetime import datetime, timezone
from functools import cache

import boto3
from botocore.exceptions import ClientError
from strands import tool

from agentic_rag.config import get_settings
from agentic_rag.text_processing import chunk_text, extract_text
from agentic_rag.tools.embeddings_client import generate_embeddings_batch
from agentic_rag.tools.vector_search import delete_document_vectors, store_document_vectors

logger = logging.getLogger(__name__)

MAX_FILE_SIZE = 10 * 1024 * 1024  # 10 MB


@cache
def _get_s3_client() -> boto3.client:
    """Get a cached S3 client."""
    settings = get_settings()
    return boto3.client("s3", region_name=settings.aws_region)


def _s3_document_key(document_id: str, filename: str) -> str:
    """Build the S3 key for a document's original file."""
    ext = filename.rsplit(".", 1)[-1] if "." in filename else "txt"
    return f"documents/{document_id}/original.{ext}"


def _s3_metadata_key(document_id: str) -> str:
    """Build the S3 key for a document's metadata file."""
    return f"documents/{document_id}/metadata.json"


@tool
def upload_document(document_id: str, filename: str) -> str:
    """Process and index a document that has already been uploaded to S3.

    Downloads the document from S3, extracts its text content, splits it into
    overlapping chunks, generates embeddings for each chunk using Amazon Titan,
    and stores the vectors in S3 Vectors for similarity search.

    The Streamlit UI uploads the raw file to S3 before calling this tool.

    Args:
        document_id: The unique identifier for the document in S3.
        filename: The original filename of the uploaded document.
    """
    settings = get_settings()
    s3 = _get_s3_client()

    # 1. Download the document from S3
    s3_key = _s3_document_key(document_id, filename)
    try:
        response = s3.get_object(Bucket=settings.documents_bucket, Key=s3_key)
        file_content = response["Body"].read()
        content_type = response.get("ContentType", "")
    except ClientError as e:
        if e.response["Error"]["Code"] == "NoSuchKey":
            return (
                f"Error: Document '{filename}' (ID: {document_id}) not found in S3 "
                f"at key '{s3_key}'. Please ensure the file was uploaded first."
            )
        logger.exception("Failed to download document from S3")
        return f"Error downloading document from S3: {e}"

    if len(file_content) > MAX_FILE_SIZE:
        return (
            f"Error: File '{filename}' is {len(file_content) / 1024 / 1024:.1f} MB, "
            f"which exceeds the {MAX_FILE_SIZE / 1024 / 1024:.0f} MB limit."
        )

    # 2. Extract text content
    try:
        text = extract_text(file_content, filename, content_type)
    except ValueError as e:
        return f"Error extracting text from '{filename}': {e}"

    # 3. Chunk the text
    chunks = chunk_text(text, settings.chunk_size, settings.chunk_overlap)
    if not chunks:
        return f"Error: No text chunks could be created from '{filename}'."

    chunk_texts = [c.text for c in chunks]

    # 4. Generate embeddings for all chunks
    try:
        embeddings = generate_embeddings_batch(chunk_texts)
    except Exception as e:
        logger.exception("Failed to generate embeddings")
        return f"Error generating embeddings for '{filename}': {e}"

    # 5. Store vectors in S3 Vectors
    try:
        stored = store_document_vectors(document_id, filename, chunk_texts, embeddings)
    except Exception as e:
        logger.exception("Failed to store vectors")
        return f"Error storing vectors for '{filename}': {e}"

    # 6. Save full chunk texts to S3 (vector metadata only stores a preview)
    chunks_data = [{"index": i, "text": t} for i, t in enumerate(chunk_texts)]
    try:
        s3.put_object(
            Bucket=settings.documents_bucket,
            Key=f"documents/{document_id}/chunks.json",
            Body=json.dumps(chunks_data),
            ContentType="application/json",
        )
    except ClientError as e:
        logger.warning("Failed to save chunk texts to S3: %s", e)

    # 7. Save document metadata to S3
    metadata = {
        "document_id": document_id,
        "filename": filename,
        "upload_timestamp": datetime.now(timezone.utc).isoformat(),
        "file_size_bytes": len(file_content),
        "content_type": content_type,
        "text_length": len(text),
        "chunk_count": len(chunks),
        "embedding_model": settings.embedding_model_id,
        "vector_dimensions": settings.vector_dimensions,
    }

    try:
        s3.put_object(
            Bucket=settings.documents_bucket,
            Key=_s3_metadata_key(document_id),
            Body=json.dumps(metadata, indent=2),
            ContentType="application/json",
        )
    except ClientError as e:
        logger.exception("Failed to save metadata")
        return (
            f"Warning: Document '{filename}' was indexed ({stored} vectors stored) "
            f"but metadata save failed: {e}"
        )

    return (
        f"Document '{filename}' processed successfully.\n"
        f"- Document ID: {document_id}\n"
        f"- Text extracted: {len(text):,} characters\n"
        f"- Chunks created: {len(chunks)}\n"
        f"- Vectors stored: {stored}\n"
        f"- Embedding model: {settings.embedding_model_id}\n"
        f"The document is now searchable in the knowledge base."
    )


@tool
def list_documents() -> str:
    """List all documents currently stored in the knowledge base.

    Retrieves metadata for every uploaded document including filename,
    upload date, file size, and number of indexed chunks.
    """
    settings = get_settings()
    s3 = _get_s3_client()

    try:
        paginator = s3.get_paginator("list_objects_v2")
        metadata_files = []
        for page in paginator.paginate(
            Bucket=settings.documents_bucket,
            Prefix="documents/",
            Delimiter="/",
        ):
            for prefix in page.get("CommonPrefixes", []):
                doc_prefix = prefix["Prefix"]
                metadata_key = f"{doc_prefix}metadata.json"
                metadata_files.append(metadata_key)
    except ClientError as e:
        logger.exception("Failed to list documents")
        return f"Error listing documents: {e}"

    if not metadata_files:
        return "No documents found in the knowledge base. Upload a document to get started."

    documents = []
    for metadata_key in metadata_files:
        try:
            response = s3.get_object(
                Bucket=settings.documents_bucket,
                Key=metadata_key,
            )
            metadata = json.loads(response["Body"].read())
            documents.append(metadata)
        except ClientError:
            doc_id = metadata_key.split("/")[1]
            documents.append({"document_id": doc_id, "filename": "Unknown", "error": True})

    header = f"Knowledge Base: {len(documents)} document(s)\n\n"
    rows = []
    for doc in documents:
        if doc.get("error"):
            rows.append(f"- {doc['document_id']}: [metadata unavailable]")
            continue

        size_kb = doc.get("file_size_bytes", 0) / 1024
        timestamp = doc.get("upload_timestamp", "Unknown")
        if isinstance(timestamp, str) and "T" in timestamp:
            timestamp = timestamp.split("T")[0]

        rows.append(
            f"- {doc.get('filename', 'Unknown')} "
            f"(ID: {doc['document_id']}, "
            f"{doc.get('chunk_count', '?')} chunks, "
            f"{size_kb:.1f} KB, "
            f"uploaded {timestamp})"
        )

    return header + "\n".join(rows)


@tool
def delete_document(document_id: str) -> str:
    """Delete a document and all its associated data from the knowledge base.

    Removes the original file, metadata, and all vector embeddings from both
    S3 storage and the S3 Vectors index.

    Args:
        document_id: The unique identifier of the document to delete.
    """
    settings = get_settings()
    s3 = _get_s3_client()

    # 1. Load metadata to get chunk count for vector deletion
    metadata_key = _s3_metadata_key(document_id)
    chunk_count = 0
    try:
        response = s3.get_object(
            Bucket=settings.documents_bucket,
            Key=metadata_key,
        )
        metadata = json.loads(response["Body"].read())
        chunk_count = metadata.get("chunk_count", 0)
        filename = metadata.get("filename", "Unknown")
    except ClientError as e:
        if e.response["Error"]["Code"] == "NoSuchKey":
            return f"Error: Document with ID '{document_id}' not found."
        logger.exception("Failed to read document metadata")
        return f"Error reading document metadata: {e}"

    errors = []

    # 2. Delete vectors from S3 Vectors
    if chunk_count > 0:
        try:
            deleted_vectors = delete_document_vectors(document_id, chunk_count)
        except Exception as e:
            errors.append(f"Vector deletion: {e}")
            deleted_vectors = 0
    else:
        deleted_vectors = 0

    # 3. Delete all S3 objects under the document prefix
    prefix = f"documents/{document_id}/"
    try:
        paginator = s3.get_paginator("list_objects_v2")
        for page in paginator.paginate(Bucket=settings.documents_bucket, Prefix=prefix):
            objects = page.get("Contents", [])
            if objects:
                s3.delete_objects(
                    Bucket=settings.documents_bucket,
                    Delete={"Objects": [{"Key": obj["Key"]} for obj in objects]},
                )
    except ClientError as e:
        errors.append(f"S3 deletion: {e}")

    if errors:
        return (
            f"Document '{filename}' (ID: {document_id}) partially deleted.\n"
            f"Vectors removed: {deleted_vectors}\n"
            f"Errors: {'; '.join(errors)}"
        )

    return (
        f"Document '{filename}' (ID: {document_id}) deleted successfully.\n"
        f"- Vectors removed: {deleted_vectors}\n"
        f"- S3 files cleaned up"
    )


def generate_document_id() -> str:
    """Generate a unique document ID."""
    return str(uuid.uuid4())
