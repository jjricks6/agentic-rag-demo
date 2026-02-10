"""Streamlit UI for Recall.

Supports two agent modes controlled by the AGENT_MODE env var:
  - "local":      Agent runs in-process (default, no AgentCore needed)
  - "agentcore":  Agent runs on AgentCore Runtime (requires AGENTCORE_RUNTIME_ARN)

Run with: streamlit run app.py
"""

import json
import logging
import uuid

import boto3
import streamlit as st

from agentic_rag.config import get_settings
from agentic_rag.tools.document_manager import generate_document_id

logging.basicConfig(level=logging.INFO, format="%(name)s - %(levelname)s - %(message)s")
logger = logging.getLogger(__name__)

ALLOWED_EXTENSIONS = ["pdf", "docx", "txt", "md"]


def init_session_state() -> None:
    """Initialize Streamlit session state on first load."""
    if "messages" not in st.session_state:
        st.session_state.messages = []

    if "session_id" not in st.session_state:
        st.session_state.session_id = str(uuid.uuid4())

    settings = get_settings()

    if "s3_client" not in st.session_state:
        st.session_state.s3_client = boto3.client("s3", region_name=settings.aws_region)

    if settings.agent_mode == "local" and "agent" not in st.session_state:
        from agentic_rag.agent import create_agent
        st.session_state.agent = create_agent()

    if settings.agent_mode == "agentcore" and "agentcore_client" not in st.session_state:
        st.session_state.agentcore_client = boto3.client(
            "bedrock-agentcore", region_name=settings.aws_region
        )


def upload_file_to_s3(uploaded_file) -> tuple[str, str]:
    """Upload a file to S3 and return (document_id, s3_key)."""
    settings = get_settings()
    document_id = generate_document_id()
    ext = uploaded_file.name.rsplit(".", 1)[-1] if "." in uploaded_file.name else "txt"
    s3_key = f"documents/{document_id}/original.{ext}"

    st.session_state.s3_client.put_object(
        Bucket=settings.documents_bucket,
        Key=s3_key,
        Body=uploaded_file.getvalue(),
        ContentType=uploaded_file.type or "application/octet-stream",
    )

    return document_id, s3_key


def _extract_text(message) -> str:
    """Extract display text from a Strands agent result message.

    The agent returns a dict like:
        {'role': 'assistant', 'content': [{'text': '...'}, ...]}
    This helper concatenates all text blocks into a single string.
    If the message is already a plain string, it's returned as-is.
    """
    if isinstance(message, str):
        return message

    if isinstance(message, dict):
        content = message.get("content", [])
        if isinstance(content, list):
            parts = [block["text"] for block in content if isinstance(block, dict) and "text" in block]
            if parts:
                return "\n\n".join(parts)
        # Fallback: if content is a plain string
        if isinstance(content, str):
            return content

    return str(message)


def send_message_local(message: str) -> str:
    """Send a message to the in-process agent."""
    result = st.session_state.agent(message)
    return _extract_text(result.message)


def send_message_agentcore(message: str) -> str:
    """Send a message to the AgentCore-hosted agent."""
    settings = get_settings()
    client = st.session_state.agentcore_client

    payload = json.dumps({"prompt": message}).encode()

    response = client.invoke_agent_runtime(
        agentRuntimeArn=settings.agentcore_runtime_arn,
        runtimeSessionId=st.session_state.session_id,
        payload=payload,
        qualifier="DEFAULT",
    )

    chunks = []
    for chunk in response.get("response", []):
        chunks.append(chunk.decode("utf-8") if isinstance(chunk, bytes) else str(chunk))

    result = json.loads("".join(chunks))
    return result.get("response", "No response from agent.")


def send_message(message: str) -> str:
    """Route to the appropriate agent backend based on AGENT_MODE."""
    settings = get_settings()
    if settings.agent_mode == "agentcore":
        return send_message_agentcore(message)
    return send_message_local(message)


def main() -> None:
    st.set_page_config(
        page_title="Recall",
        page_icon="🔍",
        layout="wide",
    )

    st.title("Recall")
    st.caption("Agentic document management and intelligent search.")

    init_session_state()

    settings = get_settings()
    mode_label = "AgentCore" if settings.agent_mode == "agentcore" else "Local"
    st.sidebar.info(f"Agent mode: **{mode_label}**")

    # --- Sidebar: Document Upload ---
    with st.sidebar:
        st.header("Document Upload")
        uploaded_file = st.file_uploader(
            "Upload a document",
            type=ALLOWED_EXTENSIONS,
            help="Supported: PDF, DOCX, TXT, Markdown (max 10 MB)",
        )

        if uploaded_file and st.button("Process Document", type="primary"):
            with st.spinner("Uploading to S3..."):
                try:
                    document_id, s3_key = upload_file_to_s3(uploaded_file)
                    st.success(f"Uploaded to S3: {uploaded_file.name}")
                except Exception as e:
                    st.error(f"Upload failed: {e}")
                    return

            user_msg = (
                f"I've uploaded a document called '{uploaded_file.name}'. "
                f"Please process it. The document_id is '{document_id}' "
                f"and the filename is '{uploaded_file.name}'."
            )
            st.session_state.messages.append({"role": "user", "content": user_msg})

            with st.spinner("Processing document (extracting, chunking, embedding)..."):
                try:
                    response = send_message(user_msg)
                    st.session_state.messages.append({"role": "assistant", "content": response})
                except Exception as e:
                    error_msg = f"Processing failed: {e}"
                    st.session_state.messages.append({"role": "assistant", "content": error_msg})

            st.rerun()

        st.divider()
        st.header("Actions")
        if st.button("List Documents"):
            st.session_state.messages.append(
                {"role": "user", "content": "List all documents in the knowledge base."}
            )
            with st.spinner("Listing documents..."):
                response = send_message("List all documents in the knowledge base.")
                st.session_state.messages.append({"role": "assistant", "content": response})
            st.rerun()

    # --- Main area: Chat ---
    for message in st.session_state.messages:
        with st.chat_message(message["role"]):
            st.markdown(message["content"])

    if prompt := st.chat_input("Ask a question about your documents..."):
        st.session_state.messages.append({"role": "user", "content": prompt})
        with st.chat_message("user"):
            st.markdown(prompt)

        with st.chat_message("assistant"):
            with st.spinner("Searching knowledge base..."):
                response = send_message(prompt)
            st.markdown(response)
        st.session_state.messages.append({"role": "assistant", "content": response})


if __name__ == "__main__":
    main()
