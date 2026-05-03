"""
oneflow_logger.py — drop-in JSON structured logger for OneFlow Python apps.

Usage:
    from oneflow_logger import get_logger
    log = get_logger("scraper", request_id="abc-123")
    log.info("started", extra={"endpoint": "/api/x", "latency_ms": 42})
    log.exception("failed")

Output: line-delimited JSON to stdout AND optionally /var/log/oneflow/{name}.log.
Promtail picks up Docker stdout (auto via docker_sd) or the file (oneflow-app-files job).

Schema fields:
  ts, level, logger, message, request_id, user_id, endpoint, latency_ms,
  error, exc_type, exc_message, exc_traceback, host, pid

Env overrides:
  ONEFLOW_LOG_LEVEL    default INFO
  ONEFLOW_LOG_FILE     1=enable file sink, 0=stdout only (default 0)
  ONEFLOW_LOG_DIR      default /var/log/oneflow
"""
from __future__ import annotations

import json
import logging
import os
import socket
import sys
import time
import traceback
from typing import Any

_HOST = socket.gethostname()
_PID = os.getpid()
_DEFAULT_LEVEL = os.environ.get("ONEFLOW_LOG_LEVEL", "INFO").upper()
_FILE_SINK = os.environ.get("ONEFLOW_LOG_FILE", "0") == "1"
_LOG_DIR = os.environ.get("ONEFLOW_LOG_DIR", "/var/log/oneflow")

_RESERVED = {
    "name", "msg", "args", "levelname", "levelno", "pathname", "filename",
    "module", "exc_info", "exc_text", "stack_info", "lineno", "funcName",
    "created", "msecs", "relativeCreated", "thread", "threadName",
    "processName", "process", "message", "asctime",
}


class JSONFormatter(logging.Formatter):
    def format(self, record: logging.LogRecord) -> str:
        payload: dict[str, Any] = {
            "ts": time.strftime("%Y-%m-%dT%H:%M:%S", time.gmtime(record.created))
            + f".{int(record.msecs):03d}Z",
            "level": record.levelname,
            "logger": record.name,
            "message": record.getMessage(),
            "host": _HOST,
            "pid": _PID,
        }

        for k, v in record.__dict__.items():
            if k in _RESERVED or k.startswith("_"):
                continue
            try:
                json.dumps(v)
                payload[k] = v
            except (TypeError, ValueError):
                payload[k] = repr(v)

        if record.exc_info:
            etype, evalue, etb = record.exc_info
            payload["error"] = str(evalue)
            payload["exc_type"] = etype.__name__ if etype else None
            payload["exc_traceback"] = "".join(traceback.format_exception(etype, evalue, etb))

        return json.dumps(payload, ensure_ascii=False)


class _MergeAdapter(logging.LoggerAdapter):
    """LoggerAdapter that merges default extras with per-call extras instead of overwriting."""

    def process(self, msg, kwargs):
        extra = dict(self.extra or {})
        if "extra" in kwargs and kwargs["extra"]:
            extra.update(kwargs["extra"])
        kwargs["extra"] = extra
        return msg, kwargs


def get_logger(name: str = "oneflow", **default_extras) -> _MergeAdapter:
    """
    Returns a logger that merges (not overwrites) per-call extras with defaults.
    Idempotent — adding handlers twice is avoided by checking existing ones.
    """
    base = logging.getLogger(name)
    base.setLevel(_DEFAULT_LEVEL)
    base.propagate = False

    if not any(isinstance(h, logging.StreamHandler) and h.stream is sys.stdout for h in base.handlers):
        sh = logging.StreamHandler(sys.stdout)
        sh.setFormatter(JSONFormatter())
        base.addHandler(sh)

    if _FILE_SINK:
        try:
            os.makedirs(_LOG_DIR, exist_ok=True)
            fh_path = os.path.join(_LOG_DIR, f"{name}.log")
            if not any(isinstance(h, logging.FileHandler) and h.baseFilename == fh_path for h in base.handlers):
                fh = logging.FileHandler(fh_path, encoding="utf-8")
                fh.setFormatter(JSONFormatter())
                base.addHandler(fh)
        except OSError:
            pass

    return _MergeAdapter(base, default_extras)


# Convenience singleton
default_logger = get_logger()
