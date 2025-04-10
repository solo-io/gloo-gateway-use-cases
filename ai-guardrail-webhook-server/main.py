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

app = FastAPI(title="Gloo AI Gateway GuardRail Webhook API", version="0.1.0")
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
    description="This webhook will be called for every request before sending the prompts to the LLM. "
    + "The 'role' and 'content' are extracted from the prompts into the PromptMessages json object "
    + "regardless of the API format from various providers.\n\n\n"
    + "Three types of responses are possible by returning one of the follow three json objects:\n\n\n"
    + "    - PassAction  : Indicates that no action is taken for the prompts and it is allow to be send to the LLM\n"
    + "    - MaskAction  : Indicates that some information are masked in the prompt and it needs to be updated before sending to the LLM\n"
    + "                    The PromptMessages json object of the request can be modified in place and send back in the body field of the\n"
    + "                    response. The number of messages inside PromptMessages MUST be the same as the request in this webhook call. \n"
    + "                    So, if the content needs to be deleted, an empty content field need to be set.\n"
    + "    - RejectAction: Indicates that the request should be rejected with the specific status code and response message. The request\n"
    + "                    will not be sent to the LLM.",
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
    description="This webhook will be called for every response from the LLM before sending back to the user. "
    + "The 'role' and 'content' are extracted from the response into the ResponseChoices json object "
    + "regardless of the API format from various providers.\n\n\n"
    + "For streaming responses from the LLM, this webhook will be called multiple times for a single response. "
    + "The AI gateway will buffer and detect the semantic boundary of the content before making the webhook call.\n\n\n"
    + "Two types of responses are possible by returning one of the follow two json objects:\n\n\n"
    + "    - PassAction: Indicates that no action is taken for the response and it is allow to be send to the user.\n"
    + "    - MaskAction: Indicates that some information are masked in the response and it needs to be updated before sending\n"
    + "                  to the user. The ResponseChoices json object from this webhook call can be modified in place and send\n"
    + "                  back in the body field in the response.\n"
    + "                  The number of choices inside ResponseChoices MUST be the same as the request in this webhook call.\n"
    + "                  So, if the content needs to be deleted, an empty content field need to be set.\n",
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
