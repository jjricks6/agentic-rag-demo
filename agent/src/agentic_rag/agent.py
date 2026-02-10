"""Strands Agent factory for the Agentic RAG system.

Creates and configures the agent with Bedrock Claude as the LLM,
document management tools, and a system prompt tailored for RAG.
"""

import logging

from strands import Agent
from strands.models.bedrock import BedrockModel

from agentic_rag.config import get_settings
from agentic_rag.tools.document_manager import delete_document, list_documents, upload_document
from agentic_rag.tools.embeddings_client import generate_embeddings
from agentic_rag.tools.vector_search import search_knowledge_base

logger = logging.getLogger(__name__)

SYSTEM_PROMPT = """\
You are an intelligent document management and retrieval assistant for the Agentic RAG Demo.

## Capabilities

1. **Document Processing**: When a user uploads a document, process it using the \
`upload_document` tool to extract text, generate embeddings, and index it for search.
2. **Knowledge Base Search**: Answer questions by searching indexed documents with \
the `search_knowledge_base` tool, then synthesizing accurate responses.
3. **Document Management**: List documents with `list_documents` and remove them \
with `delete_document`.

## How to Handle Requests

### Document Uploads
When informed that a document has been uploaded:
1. Call `upload_document` with the provided document_id and filename.
2. Report the outcome including how many chunks were indexed.

### Questions About Documents
When a user asks a question:
1. Call `search_knowledge_base` with the user's question.
2. Read the returned passages carefully.
3. Synthesize a clear answer using ONLY information from the retrieved passages.
4. Cite sources by mentioning the document filename and chunk number.
5. If no relevant passages are found, state that clearly and suggest the user \
upload relevant documents or rephrase their question.

### Document Management
- Use `list_documents` when asked what documents are available.
- Use `delete_document` when asked to remove a document.

## Response Guidelines
- Be concise but thorough. Prefer short, direct answers.
- Always cite source documents when answering from the knowledge base.
- Never fabricate information. If the knowledge base does not contain the answer, say so.
- When search results have low relevance scores, warn the user that the match may \
not be reliable.
- For ambiguous queries, ask for clarification before searching.
"""


def create_agent() -> Agent:
    """Create and configure the Agentic RAG agent.

    Uses settings from environment variables for model configuration
    and tool setup. The agent is ready to handle document upload,
    search, and management operations.

    Returns:
        A configured Strands Agent instance.
    """
    settings = get_settings()

    model = BedrockModel(
        model_id=settings.llm_model_id,
        region_name=settings.aws_region,
        max_tokens=4096,
    )

    agent = Agent(
        model=model,
        system_prompt=SYSTEM_PROMPT,
        tools=[
            upload_document,
            list_documents,
            delete_document,
            search_knowledge_base,
            generate_embeddings,
        ],
    )

    logger.info(
        "Agent created: model=%s, region=%s, env=%s",
        settings.llm_model_id,
        settings.aws_region,
        settings.environment,
    )
    return agent
