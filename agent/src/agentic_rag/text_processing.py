"""Text extraction and chunking utilities.

Supports extracting text from PDF, DOCX, TXT, and Markdown files,
then splitting into overlapping chunks for embedding generation.
"""

import io
import logging
from dataclasses import dataclass

logger = logging.getLogger(__name__)

SUPPORTED_CONTENT_TYPES = {
    "application/pdf": "pdf",
    "application/vnd.openxmlformats-officedocument.wordprocessingml.document": "docx",
    "text/plain": "txt",
    "text/markdown": "md",
}

EXTENSION_TO_TYPE = {
    ".pdf": "pdf",
    ".docx": "docx",
    ".txt": "txt",
    ".md": "md",
}


@dataclass
class TextChunk:
    """A chunk of extracted text with position metadata."""

    text: str
    index: int
    start_char: int
    end_char: int


def detect_file_type(filename: str, content_type: str | None = None) -> str:
    """Detect file type from content type or filename extension.

    Args:
        filename: Original filename.
        content_type: MIME content type, if available.

    Returns:
        File type string: 'pdf', 'docx', 'txt', or 'md'.

    Raises:
        ValueError: If the file type is not supported.
    """
    if content_type and content_type in SUPPORTED_CONTENT_TYPES:
        return SUPPORTED_CONTENT_TYPES[content_type]

    ext = "." + filename.rsplit(".", 1)[-1].lower() if "." in filename else ""
    if ext in EXTENSION_TO_TYPE:
        return EXTENSION_TO_TYPE[ext]

    raise ValueError(
        f"Unsupported file type for '{filename}' (content_type={content_type}). "
        f"Supported: PDF, DOCX, TXT, MD"
    )


def extract_text(file_content: bytes, filename: str, content_type: str | None = None) -> str:
    """Extract text content from a file.

    Args:
        file_content: Raw file bytes.
        filename: Original filename (used for type detection).
        content_type: MIME content type, if available.

    Returns:
        Extracted text content.

    Raises:
        ValueError: If the file type is not supported or extraction fails.
    """
    file_type = detect_file_type(filename, content_type)

    extractors = {
        "pdf": _extract_pdf,
        "docx": _extract_docx,
        "txt": _extract_plain_text,
        "md": _extract_plain_text,
    }

    text = extractors[file_type](file_content)
    text = text.strip()

    if not text:
        raise ValueError(f"No text content could be extracted from '{filename}'.")

    logger.info("Extracted %d characters from '%s' (%s)", len(text), filename, file_type)
    return text


def chunk_text(
    text: str,
    chunk_size: int = 4000,
    chunk_overlap: int = 800,
) -> list[TextChunk]:
    """Split text into overlapping chunks, preferring sentence boundaries.

    Uses a sliding window approach that attempts to break at natural text
    boundaries (sentences, paragraphs) to preserve semantic coherence.

    Args:
        text: The full text to split.
        chunk_size: Maximum characters per chunk.
        chunk_overlap: Characters of overlap between consecutive chunks.

    Returns:
        List of TextChunk objects with text and position metadata.
    """
    if not text:
        return []

    if len(text) <= chunk_size:
        return [TextChunk(text=text, index=0, start_char=0, end_char=len(text))]

    chunks: list[TextChunk] = []
    start = 0
    index = 0

    while start < len(text):
        end = min(start + chunk_size, len(text))

        if end < len(text):
            end = _find_break_point(text, start, end)

        chunk_text_content = text[start:end].strip()
        if chunk_text_content:
            chunks.append(
                TextChunk(
                    text=chunk_text_content,
                    index=index,
                    start_char=start,
                    end_char=end,
                )
            )
            index += 1

        next_start = end - chunk_overlap
        if next_start <= start:
            next_start = end
        start = next_start

    logger.info(
        "Split %d characters into %d chunks (size=%d, overlap=%d)",
        len(text),
        len(chunks),
        chunk_size,
        chunk_overlap,
    )
    return chunks


def _find_break_point(text: str, start: int, end: int) -> int:
    """Find the best break point near end, preferring natural boundaries."""
    search_start = max(start + 1, end - 200)
    search_text = text[search_start:end]

    for separator in ["\n\n", "\n", ". ", "! ", "? ", "; "]:
        idx = search_text.rfind(separator)
        if idx != -1:
            return search_start + idx + len(separator)

    idx = search_text.rfind(" ")
    if idx != -1:
        return search_start + idx + 1

    return end


def _extract_pdf(file_content: bytes) -> str:
    """Extract text from a PDF file."""
    from pypdf import PdfReader

    reader = PdfReader(io.BytesIO(file_content))
    pages = []
    for page in reader.pages:
        page_text = page.extract_text()
        if page_text:
            pages.append(page_text)
    return "\n\n".join(pages)


def _extract_docx(file_content: bytes) -> str:
    """Extract text from a DOCX file."""
    from docx import Document

    doc = Document(io.BytesIO(file_content))
    paragraphs = []
    for paragraph in doc.paragraphs:
        if paragraph.text.strip():
            paragraphs.append(paragraph.text)
    return "\n\n".join(paragraphs)


def _extract_plain_text(file_content: bytes) -> str:
    """Extract text from a plain text or markdown file."""
    return file_content.decode("utf-8")
