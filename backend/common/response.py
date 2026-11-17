"""Standardized JSON response helpers with MySQL type serialization."""

from datetime import date, datetime, timedelta
from decimal import Decimal
from flask import jsonify


def serialize_value(val):
    """Convert MySQL Python driver types (Decimal, date, datetime, timedelta) to JSON-safe values."""
    if isinstance(val, Decimal):
        return float(val)
    if isinstance(val, (datetime, date)):
        return val.isoformat()
    if isinstance(val, timedelta):
        total = int(val.total_seconds())
        h, rem = divmod(total, 3600)
        m, s = divmod(rem, 60)
        return f"{h:02d}:{m:02d}:{s:02d}"
    if isinstance(val, dict):
        return {k: serialize_value(v) for k, v in val.items()}
    if isinstance(val, (list, tuple)):
        return [serialize_value(item) for item in val]
    return val


def success(data=None, message: str | None = None, status: int = 200, meta: dict | None = None):
    """Return a uniform success JSON response."""
    payload: dict = {"ok": True}
    if message is not None:
        payload["message"] = message
    if data is not None:
        payload["data"] = serialize_value(data)
    if meta is not None:
        payload["meta"] = serialize_value(meta)
    return jsonify(payload), status


def error(message: str, status: int = 400, code: str | None = None, details=None):
    """Return a uniform error JSON response."""
    payload: dict = {"ok": False, "error": message}
    if code is not None:
        payload["code"] = code
    if details is not None:
        payload["details"] = serialize_value(details)
    return jsonify(payload), status
