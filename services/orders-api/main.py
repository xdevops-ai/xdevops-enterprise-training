import logging
import os
import uuid
from contextlib import asynccontextmanager

import httpx
from fastapi import FastAPI, HTTPException
from pydantic import BaseModel

from lib.database import Database, DatabaseConfig
from lib.observability import DEPENDENCY_DURATION, DEPENDENCY_REQUESTS, current_request_id, instrument, log_event

SERVICE = "orders-api"
log = logging.getLogger(SERVICE)

cfg = DatabaseConfig(
    host=os.getenv("DB_HOST", "localhost"),
    port=int(os.getenv("DB_PORT", "5432")),
    database=os.getenv("DB_NAME", "training"),
    user=os.getenv("DB_USER", "training"),
    password=os.getenv("DB_PASSWORD", ""),
    pool_size=int(os.getenv("DB_POOL_SIZE", "8")),
    acquire_timeout_seconds=float(os.getenv("DB_POOL_ACQUIRE_TIMEOUT_SECONDS", "2.0")),
    connect_timeout_seconds=float(os.getenv("DB_CONNECT_TIMEOUT_SECONDS", "2.0")),
    ssl_mode=os.getenv("DB_SSL_MODE", "verify-full"),
)
db = Database(SERVICE, cfg)

PAYMENTS_URL = os.getenv("PAYMENTS_URL", "http://payments-api")
INVENTORY_URL = os.getenv("INVENTORY_URL", "http://inventory-api")
DEPENDENCY_TIMEOUT = float(os.getenv("DEPENDENCY_TIMEOUT_SECONDS", "1.0"))

class Order(BaseModel):
    customer_id: int
    sku: str = "sku-1"
    quantity: int = 1
    amount: float = 10.0

@asynccontextmanager
async def lifespan(app: FastAPI):
    await db.start()
    yield
    await db.stop()

app = FastAPI(title="XDevOps Training Orders API", lifespan=lifespan)
instrument(app, SERVICE)

async def call_dependency(client, dependency, method, url, **kwargs):
    import time
    started = time.perf_counter()
    try:
        headers = dict(kwargs.pop("headers", {}) or {})
        headers.setdefault("x-request-id", current_request_id())
        response = await client.request(method, url, timeout=DEPENDENCY_TIMEOUT, headers=headers, **kwargs)
        response.raise_for_status()
        DEPENDENCY_REQUESTS.labels(SERVICE, dependency, "success").inc()
        return response.json()
    except Exception as exc:
        DEPENDENCY_REQUESTS.labels(SERVICE, dependency, "failure").inc()
        log_event(log, "downstream_timeout", service=SERVICE, dependency=dependency, error_type=type(exc).__name__)
        raise
    finally:
        DEPENDENCY_DURATION.labels(SERVICE, dependency).observe(time.perf_counter() - started)

@app.post("/orders")
async def create_order(order: Order):
    order_id = str(uuid.uuid4())
    async with httpx.AsyncClient() as client:
        try:
            await call_dependency(
                client, "inventory-api", "POST", f"{INVENTORY_URL}/inventory/reserve",
                json={"sku": order.sku, "quantity": order.quantity},
            )
            await call_dependency(
                client, "payments-api", "POST", f"{PAYMENTS_URL}/payment/authorize",
                json={"order_id": order_id, "amount": order.amount},
            )
        except Exception as exc:
            raise HTTPException(status_code=502, detail="downstream dependency failed") from exc

    try:
        await db.execute(
            "INSERT INTO orders(id, customer_id, sku, quantity, amount) VALUES($1,$2,$3,$4,$5)",
            uuid.UUID(order_id), order.customer_id, order.sku, order.quantity, order.amount,
        )
    except Exception as exc:
        raise HTTPException(status_code=500, detail="database dependency unavailable") from exc

    return {"id": order_id, "status": "created"}

@app.get("/orders/{order_id}")
async def get_order(order_id: uuid.UUID):
    try:
        row = await db.fetchrow(
            "SELECT id, customer_id, sku, quantity, amount, created_at FROM orders WHERE id = $1",
            order_id,
        )
    except Exception as exc:
        raise HTTPException(status_code=500, detail="database dependency unavailable") from exc
    if not row:
        raise HTTPException(status_code=404, detail="order not found")
    return dict(row)
