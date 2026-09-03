import asyncio
import logging
import time
from dataclasses import dataclass

import asyncpg
from prometheus_client import Counter, Gauge, Histogram

from .observability import log_event

DB_ATTEMPTS = Counter("training_db_connection_attempts_total", "DB connection attempts", ["service"])
DB_FAILURES = Counter("training_db_connection_failures_total", "DB connection failures", ["service", "error_type"])
DB_DURATION = Histogram(
    "training_db_operation_duration_seconds",
    "Database operation duration",
    ["service"],
    buckets=(0.01, 0.05, 0.1, 0.2, 0.5, 1, 2, 5, 10),
)
DB_POOL_MAX = Gauge("training_db_pool_max_connections", "Configured DB pool max", ["service"])
DB_POOL_IN_USE = Gauge("training_db_pool_in_use_connections", "Approximate acquired DB pool connections", ["service"])

@dataclass
class DatabaseConfig:
    host: str
    port: int
    database: str
    user: str
    password: str
    pool_size: int = 10
    acquire_timeout_seconds: float = 2.0
    connect_timeout_seconds: float = 2.0
    ssl_mode: str = "verify-full"

class Database:
    def __init__(self, service: str, cfg: DatabaseConfig):
        self.service = service
        self.cfg = cfg
        self.log = logging.getLogger(service)
        self.pool: asyncpg.Pool | None = None
        DB_POOL_MAX.labels(service).set(cfg.pool_size)

    async def start(self):
        # min_size=0 means app startup remains independent from the DB.
        # max_queries=1 intentionally forces frequent new connections so an NSG change
        # becomes visible quickly rather than being hidden by long-lived TCP sessions.
        self.pool = await asyncpg.create_pool(
            host=self.cfg.host,
            port=self.cfg.port,
            database=self.cfg.database,
            user=self.cfg.user,
            password=self.cfg.password,
            min_size=0,
            max_size=self.cfg.pool_size,
            timeout=self.cfg.connect_timeout_seconds,
            command_timeout=5,
            max_queries=1,
            max_inactive_connection_lifetime=5,
            ssl=self.cfg.ssl_mode,
        )

    async def stop(self):
        if self.pool:
            await self.pool.close()

    async def fetchrow(self, sql: str, *args):
        if not self.pool:
            raise RuntimeError("database pool not initialized")
        started = time.perf_counter()
        DB_ATTEMPTS.labels(self.service).inc()
        DB_POOL_IN_USE.labels(self.service).inc()
        try:
            async with asyncio.timeout(self.cfg.acquire_timeout_seconds):
                async with self.pool.acquire() as conn:
                    row = await conn.fetchrow(sql, *args)
                    DB_DURATION.labels(self.service).observe(time.perf_counter() - started)
                    return row
        except Exception as exc:
            err = type(exc).__name__
            DB_FAILURES.labels(self.service, err).inc()
            log_event(
                self.log,
                "database_connection_timeout" if isinstance(exc, (TimeoutError, asyncio.TimeoutError)) else "database_operation_failed",
                service=self.service,
                dependency="postgresql",
                error_type=err,
                duration_ms=round((time.perf_counter() - started) * 1000, 1),
            )
            raise
        finally:
            DB_POOL_IN_USE.labels(self.service).dec()

    async def execute(self, sql: str, *args):
        if not self.pool:
            raise RuntimeError("database pool not initialized")
        started = time.perf_counter()
        DB_ATTEMPTS.labels(self.service).inc()
        DB_POOL_IN_USE.labels(self.service).inc()
        try:
            async with asyncio.timeout(self.cfg.acquire_timeout_seconds):
                async with self.pool.acquire() as conn:
                    result = await conn.execute(sql, *args)
                    DB_DURATION.labels(self.service).observe(time.perf_counter() - started)
                    return result
        except Exception as exc:
            err = type(exc).__name__
            DB_FAILURES.labels(self.service, err).inc()
            log_event(
                self.log,
                "database_connection_timeout" if isinstance(exc, (TimeoutError, asyncio.TimeoutError)) else "database_operation_failed",
                service=self.service,
                dependency="postgresql",
                error_type=err,
                duration_ms=round((time.perf_counter() - started) * 1000, 1),
            )
            raise
        finally:
            DB_POOL_IN_USE.labels(self.service).dec()
