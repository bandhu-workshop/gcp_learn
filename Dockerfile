FROM ghcr.io/astral-sh/uv:python3.12-trixie-slim

WORKDIR /work

COPY pyproject.toml uv.lock ./
RUN uv sync --frozen

COPY . .

# Cloud Run expects the container to listen on 8080. This is non-negotiable.
CMD ["uv", "run", "uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8080"]