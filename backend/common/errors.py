"""Custom application exceptions and global Flask error handlers."""

from flask import Flask
from werkzeug.exceptions import HTTPException

from common.response import error
from config.db import (
    DatabaseConstraintError,
    DatabaseDuplicateError,
    DatabaseError,
    DatabaseTriggerError,
    DatabaseUnavailableError,
)


class AppError(Exception):
    """Application-level HTTP error."""

    def __init__(self, message: str, status_code: int = 400, code: str | None = None, details=None):
        super().__init__(message)
        self.message = message
        self.status_code = status_code
        self.code = code
        self.details = details


def register_error_handlers(app: Flask) -> None:
    """Attach JSON error handlers to the Flask app."""

    @app.errorhandler(AppError)
    def handle_app_error(exc: AppError):
        return error(exc.message, status=exc.status_code, code=exc.code, details=exc.details)

    @app.errorhandler(DatabaseTriggerError)
    def handle_db_trigger(exc: DatabaseTriggerError):
        return error(exc.message, status=400, code="DB_TRIGGER_VIOLATION", details={"errno": exc.errno})

    @app.errorhandler(DatabaseDuplicateError)
    def handle_db_duplicate(exc: DatabaseDuplicateError):
        return error(exc.message, status=409, code="DB_DUPLICATE_ENTRY", details={"errno": exc.errno})

    @app.errorhandler(DatabaseConstraintError)
    def handle_db_constraint(exc: DatabaseConstraintError):
        return error(exc.message, status=400, code="DB_CONSTRAINT_VIOLATION", details={"errno": exc.errno})

    @app.errorhandler(DatabaseUnavailableError)
    def handle_db_unavailable(exc: DatabaseUnavailableError):
        return error(exc.message, status=503, code="DB_UNAVAILABLE")

    @app.errorhandler(DatabaseError)
    def handle_db_error(exc: DatabaseError):
        return error(exc.message, status=exc.status_code, code="DB_ERROR", details={"errno": exc.errno})

    @app.errorhandler(HTTPException)
    def handle_http_exception(exc: HTTPException):
        return error(exc.description or exc.name, status=exc.code or 500, code=f"HTTP_{exc.code}")

    @app.errorhandler(Exception)
    def handle_unexpected(exc: Exception):
        return error(f"Lỗi hệ thống không mong muốn: {exc}", status=500, code="INTERNAL_ERROR")
