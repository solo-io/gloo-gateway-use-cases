# Sample Python Webhook Server to receive Gloo AI Gateway Guardrail webhook calls

## Prerequisite

This application uses `uv` for dependency and python env management. Please follow the uv [installation instruction](https://docs.astral.sh/uv/getting-started/installation/) for your platform.

## Description

This server is very basic for just demonstrating the webhook API and what action you can take after examining the content.

If the content contains the word "block", it will return 403. If the content contains the word "mask", it will change it to "****" and return the entire body in a 200 response.

On the upstream request path, block, mask or pass actions are allowed. Base on these responses from the webhook server, Gloo AI Gateway will either block the request from going to upstream LLM server or use the masked content in the body of the response for sending upstream. The format of the message in these webhook api is loosely based on the OpenAI Chat Completion API format and is independent of what model/API upstream uses. Gloo AI Gateway will translate the masked message back to the proper format for the upstream model/API.  

On the downstream response path, only mask or pass action is allow and similarly, Gloo AI Gateway will translate the message to the correct format for sending to the end user.

## Starting the server

```bash
uv run uvicorn main:app --host 0.0.0.0 --port 8000 --reload
```

## Swagger Interactive API page

Open the following URL in your browser to read the API documentation and test with sample request

```bash
http://localhost:8000/docs
```

## Sample Resources

See the resources/ directory for simple setup for turning on the GuardRail Webhook Feature.
The prompt-guard-webhook.yaml file is where the webhook server ip is setup.

## Open API Spec

The gloo-ai-gateway-guardrail-webhook-openapi.yaml file under the docs/ directory is the generated Open API spec file. The json version can also be retrieved from `http://localhost:8000/openapi.json` while this sample server is running.

## Open Tracing

Gloo AI Gateway supports Open Tracing and will propagate the tracing header to the webhook server if the tracing feature is enabled. You can set the OTEL_EXPORTER_OTLP_TRACES_ENDPOINT env variable to point to your tracing server and the server will export the trace.
