import os
import signal
import sys
from typing import Annotated
from fastapi import FastAPI, Header, Request

from opentelemetry.exporter.otlp.proto.grpc.trace_exporter import OTLPSpanExporter
from opentelemetry.instrumentation.fastapi import FastAPIInstrumentor
from opentelemetry.propagate import extract
from opentelemetry.sdk.trace import TracerProvider
from opentelemetry.sdk.trace.export import (
    BatchSpanProcessor,
)
from opentelemetry.sdk.resources import (
    SERVICE_NAME,
    Resource,
)
from opentelemetry import trace
import uvicorn
import webhook_api as api

app = FastAPI(
    title="Gloo AI Gateway GuardRail Webhook API",
    version="0.1.0",
    description="""
This API specification defines the webhook endpoints for the Gloo AI Gateway Guardrail feature. The Guardrail feature provides a way to intercept and process both requests to and responses from Large Language Models (LLMs). This way, you can implement your own advanced guardrails and content filtering.

The Guardrail feature consists of two main webhook endpoints:

1. `/request` - Processes request prompts before they are sent to the LLM
2. `/response` - Processes responses from the LLM before they are sent back to the user

Each endpoint supports different actions:

* `PassAction`: Allow the content to pass through unchanged
* `MaskAction`: Modify the content by masking sensitive information
* `RejectAction`: Block the content and return an error response

The API is designed to work with various LLM providers by normalizing their different request and response formats into a consistent schema.
    """,
)
FastAPIInstrumentor().instrument_app(app)

def tracer() -> trace.Tracer | trace.NoOpTracer:
    # To export tracing to a server (eg jaeger):
    #    export OTEL_EXPORTER_OTLP_TRACES_ENDPOINT="<server_ip>:4317"
    endpoint = os.getenv("OTEL_EXPORTER_OTLP_TRACES_ENDPOINT")
    if endpoint is None or len(endpoint) == 0:
        return trace.NoOpTracer()

    # Initialize tracer provider
    resource = Resource.create(attributes={SERVICE_NAME: "gloo-ai-webhook"})
    tracer_provider = TracerProvider(resource=resource)
    # Configure span processor and exporter
    span_processor = BatchSpanProcessor(
        OTLPSpanExporter(
            # endpoint="localhost:4317",
            endpoint=endpoint,
            insecure=True,
        )
    )
    tracer_provider.add_span_processor(span_processor)
    return tracer_provider.get_tracer(__name__)


@app.middleware("http")
async def add_tracing(request: Request, call_next):
    span_name = f"gloo-ai-{os.path.basename(request.url.path)}-webhook"
    print(f"adding trace for {span_name}")
    print(f"trace context {extract(request.headers)}")
    with tracer().start_as_current_span(span_name, context=extract(request.headers)):
        response = await call_next(request)
    return response


@app.post(
    "/request",
    response_model=api.GuardrailsPromptResponse,
    tags=["Webhooks"],
    description="This webhook intercepts requests from the user before they are sent to the LLM. You can use it to:\n"
    "- Validate and filter content\n"
    "- Mask sensitive information\n"
    "- Reject requests based on policy rules\n\n"
    "The webhook receives normalized prompt messages regardless of the original LLM provider's format.\n"
    "It can return one of three actions:\n"
    "1. `PassAction`: Allow the request to proceed unchanged\n"
    "2. `MaskAction`: Return modified prompts with sensitive information masked\n"
    "3. `RejectAction`: Block the request with a specified HTTP status code and message"
)
async def process_prompts(
    req: api.GuardrailsPromptRequest,
) -> api.GuardrailsPromptResponse:
    should_mask_prompts = False
    for i, message in enumerate(req.body.messages):
        if len(message.content) == 0:
            continue
        print(f"role: {message.role}")
        print(f"content: {message.content}")
        
        # This is just a simple check to demonstrate how to block the request completely.
        # Replace with function that detect if the prompt should be blocked
        if "block" in message.content:
            return api.GuardrailsPromptResponse(
                action=api.RejectAction(
                    body="request blocked",
                    status_code=403,
                    reason="Inappropriate content detected",
                ),
            )

        if "mask" in message.content:
            req.body.messages[i].content = message.content.replace("mask", "****")
            should_mask_prompts = True

    if should_mask_prompts:
        return api.GuardrailsPromptResponse(
            action=api.MaskAction(
                body=req.body,
                reason="Sensitive content detected",
            ),
        )

    # Let the prompt pass and go upstream
    return api.GuardrailsPromptResponse(
        action=api.PassAction(reason="passed"),
    )


@app.post(
    "/response",
    response_model=api.GuardrailsResponseResponse,
    tags=["Webhooks"],
    description="This webhook intercepts responses from the LLM before they are returned to the user. The `role` and `content` "
    "are extracted from the response into the `ResponseChoices` JSON object, regardless of the API format from various "
    "providers.\n\n"
    "For streaming responses from the LLM, this webhook is called multiple times for a single response. "
    "The AI gateway buffers and detects the semantic boundary of the content before making the webhook call.\n\n"
    "Two types of responses are possible by returning one of the following JSON objects:\n\n"
    "1. `PassAction`: \n"
    "   - Indicates that no action is taken for the response\n"
    "   - The response is allowed to be sent to the user unchanged\n\n"
    "2. `MaskAction`: \n"
    "   - Indicates that some information is masked in the response\n"
    "   - The `ResponseChoices` JSON object can be modified in place\n"
    "   - The modified object should be sent back in the body field of the response\n"
    "   - The number of choices inside `ResponseChoices` MUST be the same as in the request\n"
    "   - If content needs to be deleted, set an empty content field"
)
async def process_responses(
    request: Request,
    req: api.GuardrailsResponseRequest,
) -> api.GuardrailsResponseResponse:
    should_mask_content = False
    for i, choice in enumerate(req.body.choices):
        if "mask" in choice.message.content:
            req.body.choices[i].message.content = choice.message.content.replace("mask", "****")
            should_mask_content = True

    if should_mask_content:
        return api.GuardrailsResponseResponse(
            action=api.MaskAction(
                body=req.body,
                reason="Sensitive content detected",
            ),
        )

    return api.GuardrailsResponseResponse(
        action=api.PassAction(reason="passed"),
    )

def main():
    uvicorn.run(app, host="0.0.0.0", port=8000)
