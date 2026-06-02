import logging
import os
from typing import Any, Dict

import psycopg2
import redis
from fastapi import FastAPI
from prometheus_fastapi_instrumentator import Instrumentator

LOG_LEVEL = os.getenv("LOG_LEVEL", "INFO").upper()

logging.basicConfig(
    level=LOG_LEVEL,
    format="%(asctime)s %(levelname)s %(name)s %(message)s",
)
logger = logging.getLogger("app")

app = FastAPI(title="FastAPI Minimal Stack", version="1.0.0")

# Expose Prometheus metrics at /metrics
Instrumentator().instrument(app).expose(app)


def _check_postgres() -> Dict[str, Any]:
    database_url = os.getenv("DATABASE_URL")
    if not database_url:
        return {"ok": False, "error": "DATABASE_URL not set"}
    try:
        conn = psycopg2.connect(database_url, connect_timeout=2)
        with conn.cursor() as cur:
            cur.execute("SELECT 1")
            cur.fetchone()
        conn.close()
        return {"ok": True}
    except Exception as exc:
        logger.exception("Postgres health check failed")
        return {"ok": False, "error": str(exc)}


def _check_redis() -> Dict[str, Any]:
    redis_url = os.getenv("REDIS_URL")
    if not redis_url:
        return {"ok": False, "error": "REDIS_URL not set"}
    try:
        client = redis.Redis.from_url(redis_url, socket_connect_timeout=2)
        client.ping()
        return {"ok": True}
    except Exception as exc:
        logger.exception("Redis health check failed")
        return {"ok": False, "error": str(exc)}


@app.get("/")
def root() -> Dict[str, str]:
    return {"message": "Hello from FastAPI"}


@app.get("/health")
def health() -> Dict[str, Any]:
    postgres = _check_postgres()
    redis_state = _check_redis()
    ok = postgres["ok"] and redis_state["ok"]
    return {
        "ok": ok,
        "postgres": postgres,
        "redis": redis_state,
    }
