"""Strands Agent tools for the Agentic RAG system.

Exposes three tool modules matching the architecture:
  - document_manager: S3 document upload, listing, and deletion
  - embeddings_client: Bedrock Titan embedding generation
  - vector_search: S3 Vectors similarity search and storage
"""

from agentic_rag.tools.document_manager import (
    delete_document,
    list_documents,
    upload_document,
)
from agentic_rag.tools.vector_search import search_knowledge_base

__all__ = [
    "upload_document",
    "list_documents",
    "delete_document",
    "search_knowledge_base",
]
