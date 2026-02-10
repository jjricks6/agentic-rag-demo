"""AgentCore Runtime entry point for the Agentic RAG agent.

This is the entry point that AgentCore invokes when the agent receives a request.
Deploy with: cd agent && agentcore deploy

The agent accepts a JSON payload with a "prompt" field and returns the agent's
response. All tool orchestration (document processing, search, etc.) is handled
by the Strands Agent based on its system prompt.
"""

import logging

from bedrock_agentcore.runtime import BedrockAgentCoreApp

from agentic_rag.agent import create_agent

logging.basicConfig(level=logging.INFO, format="%(name)s - %(levelname)s - %(message)s")
logger = logging.getLogger(__name__)

app = BedrockAgentCoreApp()

# Create agent once at module level so it persists across invocations
# within the same container (avoids cold-start overhead on warm requests).
agent = create_agent()


@app.entrypoint
def invoke(payload):
    """Handle agent invocations from AgentCore Runtime.

    Expected payload:
        {"prompt": "Your question or instruction here"}

    Returns:
        {"response": "Agent's response text"}
    """
    prompt = payload.get("prompt", "")
    if not prompt:
        return {"response": "No prompt provided.", "status": "error"}

    logger.info("Processing prompt: %.100s...", prompt)

    try:
        result = agent(prompt)
        return {"response": result.message}
    except Exception as e:
        logger.exception("Agent invocation failed")
        return {"response": f"Agent error: {e}", "status": "error"}


if __name__ == "__main__":
    app.run()
