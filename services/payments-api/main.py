import asyncio
import logging
import os
import random

from fastapi import FastAPI, HTTPException
from pydantic import BaseModel

from lib.observability import instrument, log_event

SERVICE = "payments-api"
log = logging.getLogger(SERVICE)
app = FastAPI(title="XDevOps Training Payments API")
instrument(app, SERVICE)

class Payment(BaseModel):
    order_id: str
    amount: float

@app.post("/payment/authorize")
async def authorize(payment: Payment):
    mode = os.getenv("FAULT_MODE", "normal").lower()
    baseline_ms = int(os.getenv("BASE_LATENCY_MS", "80"))
    fault_ms = int(os.getenv("FAULT_LATENCY_MS", "3000"))

    if mode == "slow":
        await asyncio.sleep(fault_ms / 1000)
    else:
        await asyncio.sleep((baseline_ms + random.randint(0, 30)) / 1000)

    if mode == "error":
        log_event(log, "payment_provider_error", service=SERVICE, order_id=payment.order_id)
        raise HTTPException(status_code=502, detail="payment provider error")
    if mode == "unavailable":
        log_event(log, "payment_provider_unavailable", service=SERVICE, order_id=payment.order_id)
        raise HTTPException(status_code=503, detail="payment provider unavailable")
    if mode == "rate_limit":
        raise HTTPException(status_code=429, detail="payment provider rate limited")

    return {"status": "approved", "order_id": payment.order_id, "amount": payment.amount}
