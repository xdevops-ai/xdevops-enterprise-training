import asyncio
import os
import random
import signal
import uuid

import httpx

CUSTOMER_URL = os.getenv("CUSTOMER_URL", "http://customer-api")
ORDERS_URL = os.getenv("ORDERS_URL", "http://orders-api")
MODE = os.getenv("LOAD_MODE", "normal")

PROFILES = {
    "idle": (0.2, 1),
    "normal": (5.0, 5),
    "busy": (20.0, 20),
    "stress": (60.0, 80),
}
RPS, CONCURRENCY = PROFILES.get(MODE, PROFILES["normal"])
stop = asyncio.Event()

async def one_request(client: httpx.AsyncClient):
    headers = {"x-request-id": str(uuid.uuid4())}
    if random.random() < 0.8:
        cid = random.randint(1, 20)
        await client.get(f"{CUSTOMER_URL}/customers/{cid}", timeout=5, headers=headers)
    else:
        cid = random.randint(1, 20)
        await client.post(
            f"{ORDERS_URL}/orders",
            json={"customer_id": cid, "sku": f"sku-{random.randint(1,3)}", "quantity": 1, "amount": 10.0},
            timeout=5,
            headers=headers,
        )

async def worker():
    interval = 1.0 / max(RPS / max(CONCURRENCY, 1), 0.01)
    async with httpx.AsyncClient() as client:
        while not stop.is_set():
            try:
                await one_request(client)
            except Exception:
                pass
            await asyncio.sleep(interval)

async def main():
    loop = asyncio.get_running_loop()
    for sig in (signal.SIGTERM, signal.SIGINT):
        loop.add_signal_handler(sig, stop.set)
    await asyncio.gather(*(worker() for _ in range(CONCURRENCY)))

if __name__ == "__main__":
    asyncio.run(main())
