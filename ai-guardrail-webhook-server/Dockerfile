# From uv docs
# https://docs.astral.sh/uv/guides/integration/docker/#installing-uv

# First stage: build dependencies
FROM --platform=linux/amd64 python:3.11-slim AS builder

WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Second stage: runtime
FROM --platform=linux/amd64 python:3.11-slim

WORKDIR /app
COPY --from=builder /usr/local/lib/python3.11/site-packages /usr/local/lib/python3.11/site-packages
COPY main.py .
COPY webhook_api.py .
COPY docs/ docs/

EXPOSE 8000

# Use the full path to Python and ensure it's executable
RUN chmod +x /usr/local/bin/python
CMD ["/usr/local/bin/python", "-m", "uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"]

