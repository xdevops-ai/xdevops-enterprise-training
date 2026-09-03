import logging
import os
from contextlib import asynccontextmanager

from fastapi import FastAPI, HTTPException

from lib.database import Database, DatabaseConfig
from lib.observability import instrument, log_event

SERVICE = "customer-api"
log = logging.getLogger(SERVICE)

def env(name, default=None):
    return os.getenv(name, default)

cfg = DatabaseConfig(
    host=env("DB_HOST", "localhost"),
    port=int(env("DB_PORT", "5432")),
    database=env("DB_NAME", "training"),
    user=env("DB_USER", "training"),
    password=env("DB_PASSWORD", ""),
    pool_size=int(env("DB_POOL_SIZE", "10")),
    acquire_timeout_seconds=float(env("DB_POOL_ACQUIRE_TIMEOUT_SECONDS", "2.0")),
    connect_timeout_seconds=float(env("DB_CONNECT_TIMEOUT_SECONDS", "2.0")),
    ssl_mode=env("DB_SSL_MODE", "verify-full"),
)
db = Database(SERVICE, cfg)
QUERY_LATENCY_SECONDS = float(env("DB_QUERY_LATENCY_SECONDS", "0.10"))

@asynccontextmanager
async def lifespan(app: FastAPI):
    await db.start()
    log_event(log, "service_started", service=SERVICE, db_pool_size=cfg.pool_size)
    yield
    await db.stop()

app = FastAPI(title="XDevOps Training Customer API", lifespan=lifespan)
instrument(app, SERVICE)

@app.get("/customers/{customer_id}")
async def get_customer(customer_id: int):
    try:
        row = await db.fetchrow(
            "SELECT id, name, tier, pg_sleep($2) FROM customers WHERE id = $1",
            customer_id, QUERY_LATENCY_SECONDS,
        )
    except Exception as exc:
        raise HTTPException(status_code=500, detail="database dependency unavailable") from exc
    if not row:
        raise HTTPException(status_code=404, detail="customer not found")
    return {"id": row["id"], "name": row["name"], "tier": row["tier"]}

@app.get("/customers/{customer_id}/orders")
async def customer_orders(customer_id: int):
    try:
        row = await db.fetchrow("SELECT count(*) AS count, pg_sleep($2) FROM orders WHERE customer_id = $1", customer_id, QUERY_LATENCY_SECONDS)
    except Exception as exc:
        raise HTTPException(status_code=500, detail="database dependency unavailable") from exc
    return {"customer_id": customer_id, "order_count": row["count"]}

@app.get("/dependency-health")
async def dependency_health():
    try:
        row = await db.fetchrow("SELECT now() AS now")
        return {"postgresql": "ok", "server_time": str(row["now"])}
    except Exception as exc:
        return {"postgresql": "failed", "error_type": type(exc).__name__}
