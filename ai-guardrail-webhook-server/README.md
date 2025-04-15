# Sample Python Webhook Server to receive Gloo AI Gateway Guardrail webhook calls

This server demonstrates how to implement a webhook for the Gloo AI Gateway Guardrail feature. The Guardrail feature allows you to intercept and process both requests to and responses from Large Language Models (LLMs).

### Features

**Request Processing**: Intercepts user prompts before they reach the LLM to:
  - Support three actions: Pass, Mask, or Reject
  - Validate, filter, or mask sensitive content
  - Normalize prompts across different LLM providers

**Response Processing**: Intercepts LLM responses before they reach the user to:
  - Support two actions: Pass or Mask
  - Filter or mask sensitive content in responses
  - Handle both single and streaming responses

### Example Behavior

The webhook server is preconfigured to support the following actions:

- If content contains "block", returns HTTP 403
- If content contains "mask", replaces "mask" with "****"
- Otherwise, allows the content to pass through unchanged

The webhook API format is based on the OpenAI Chat Completion API format, but works independently of the upstream model and API. Gloo AI Gateway handles the translation between different formats.

## Prerequisites

- Python 3.11 or later
- pip (Python package installer)

## Starting the server locally

First, create and activate a virtual environment:

```bash
# Create a virtual environment
python -m venv venv

# Activate the virtual environment
# On macOS/Linux:
source venv/bin/activate
# On Windows:
# .\venv\Scripts\activate
```

Then install the dependencies:

```bash
pip install -r requirements.txt
```

Finally, start the server:

```bash
uvicorn main:app --host 0.0.0.0 --port 8000 --reload
```

When you're done, you can deactivate the virtual environment:

```bash
deactivate
```

## Swagger Interactive API page

Open the following URL in your browser to read the API documentation and test with sample request:

```bash
http://localhost:8000/docs
```

## Sample Resources

See the `resources/` directory for simple setup for turning on the GuardRail Webhook Feature.

The `prompt-guard-webhook.yaml` file is where the webhook server ip is setup.

The `Dockerfile` is used to build a sample Docker image for the webhook server:

```
gcr.io/solo-public/docs/ai-guardrail-webhook:latest
```

## Open API Spec

The `gloo-ai-gateway-guardrail-webhook-openapi.yaml` file under the `docs/` directory is the generated Open API spec file. The json version can also be retrieved from `http://localhost:8000/openapi.json` while this sample server is running.

## Open Tracing

Gloo AI Gateway supports Open Tracing and will propagate the tracing header to the webhook server if the tracing feature is enabled. You can set the `OTEL_EXPORTER_OTLP_TRACES_ENDPOINT` env variable to point to your tracing server and the server will export the trace.
