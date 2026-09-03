import asyncio
import logging
import os

from fastapi import FastAPI, HTTPException
from pydantic import BaseModel

from lib.observability import instrument, log_event

SERVICE = "inventory-api"
log = logging.getLogger(SERVICE)
app = FastAPI(title="XDevOps Training Inventory API")
instrument(app, SERVICE)

STOCK = {"sku-1": 1000, "sku-2": 1000, "sku-3": 1000}
_leak = []

class Reservation(BaseModel):
    sku: str
    quantity: int = 1

@app.on_event("startup")
async def maybe_start_memory_fault():
    if os.getenv("FAULT_MODE", "normal").lower() == "memory":
        asyncio.create_task(memory_leak())

async def memory_leak():
    chunk_mb = int(os.getenv("FAULT_MEMORY_CHUNK_MB", "8"))
    interval = float(os.getenv("FAULT_MEMORY_INTERVAL_SECONDS", "1"))
    log_event(log, "memory_fault_started", service=SERVICE, chunk_mb=chunk_mb, interval_seconds=interval)
    while True:
        _leak.append(bytearray(chunk_mb * 1024 * 1024))
        await asyncio.sleep(interval)

@app.get("/inventory/{sku}")
async def get_inventory(sku: str):
    return {"sku": sku, "available": STOCK.get(sku, 0)}

@app.post("/inventory/reserve")
async def reserve(r: Reservation):
    available = STOCK.get(r.sku, 0)
    if available < r.quantity:
        raise HTTPException(status_code=409, detail="insufficient inventory")
    STOCK[r.sku] = available - r.quantity
    return {"sku": r.sku, "reserved": r.quantity, "remaining": STOCK[r.sku]}
