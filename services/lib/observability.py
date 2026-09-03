import json
import logging
import os
import time
import uuid
from contextvars import ContextVar
from typing import Callable

from fastapi import FastAPI, Request, Response
from prometheus_client import CONTENT_TYPE_LATEST, Counter, Histogram, generate_latest

_request_id: ContextVar[str] = ContextVar("request_id", default="-")
_environment = os.getenv("ENVIRONMENT", "training")

HTTP_REQUESTS = Counter(
    "training_http_requests_total",
    "HTTP requests handled by training services",
    ["service", "method", "path", "status"],
)
HTTP_DURATION = Histogram(
    "training_http_request_duration_seconds",
    "HTTP request duration in seconds",
    ["service", "method", "path"],
    buckets=(0.01, 0.025, 0.05, 0.1, 0.25, 0.5, 1, 2, 5, 10),
)
DEPENDENCY_REQUESTS = Counter(
    "training_dependency_requests_total",
    "Dependency calls",
    ["service", "dependency", "result"],
)
DEPENDENCY_DURATION = Histogram(
    "training_dependency_request_duration_seconds",
    "Dependency call duration in seconds",
    ["service", "dependency"],
    buckets=(0.01, 0.05, 0.1, 0.25, 0.5, 1, 2, 5, 10),
)


class JsonFormatter(logging.Formatter):
    def format(self, record: logging.LogRecord) -> str:
        payload = {
            "timestamp": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
            "level": record.levelname,
            "logger": record.name,
            "service": record.name,
            "environment": _environment,
            "message": record.getMessage(),
            "request_id": _request_id.get(),
        }
        extra = getattr(record, "structured", None)
        if isinstance(extra, dict):
            payload.update(extra)
        return json.dumps(payload, default=str, separators=(",", ":"))


def configure_logging() -> None:
    handler = logging.StreamHandler()
    handler.setFormatter(JsonFormatter())
    root = logging.getLogger()
    root.handlers.clear()
    root.addHandler(handler)
    root.setLevel(logging.INFO)


def log_event(logger: logging.Logger, event: str, **fields) -> None:
    logger.info(event, extra={"structured": {"event": event, **fields}})


def current_request_id() -> str:
    """Return the request correlation ID for downstream propagation."""
    return _request_id.get()


def _route_template(request: Request) -> str:
    route = request.scope.get("route")
    return getattr(route, "path", request.url.path)


def instrument(app: FastAPI, service_name: str) -> None:
    configure_logging()
    logger = logging.getLogger(service_name)

    @app.middleware("http")
    async def metrics_and_request_context(request: Request, call_next: Callable):
        rid = request.headers.get("x-request-id") or str(uuid.uuid4())
        token = _request_id.set(rid)
        started = time.perf_counter()
        status = 500
        try:
            response: Response = await call_next(request)
            status = response.status_code
            response.headers["x-request-id"] = rid
            return response
        finally:
            path = _route_template(request)
            elapsed = time.perf_counter() - started
            HTTP_REQUESTS.labels(service_name, request.method, path, str(status)).inc()
            HTTP_DURATION.labels(service_name, request.method, path).observe(elapsed)
            if path not in ("/health", "/ready", "/metrics"):
                log_event(
                    logger,
                    "http_request_completed",
                    method=request.method,
                    path=path,
                    status=status,
                    duration_ms=round(elapsed * 1000, 1),
                )
            _request_id.reset(token)

    @app.get("/health", include_in_schema=False)
    async def health():
        return {"status": "ok", "service": service_name}

    # Process readiness is intentionally separate from dependency health.
    # The cross-layer lab relies on Running/Ready pods while PostgreSQL is unreachable.
    @app.get("/ready", include_in_schema=False)
    async def ready():
        return {"status": "ready", "service": service_name}

    @app.get("/metrics", include_in_schema=False)
    async def metrics():
        return Response(generate_latest(), media_type=CONTENT_TYPE_LATEST)
