"""MySQL connection pool and query helpers for Podify."""

from contextlib import contextmanager
import threading
import time
import mysql.connector
from mysql.connector import Error as MySQLError
from mysql.connector import pooling

from config.settings import Settings


class DatabaseError(Exception):
    """Base exception for database-layer errors."""

    def __init__(self, message: str, status_code: int = 500, errno: int | None = None):
        super().__init__(message)
        self.message = message
        self.status_code = status_code
        self.errno = errno


class DatabaseUnavailableError(DatabaseError):
    """Raised when MySQL server cannot be reached or pool cannot initialize."""

    def __init__(self, message: str = "Không thể kết nối đến MySQL Server."):
        super().__init__(message, status_code=503)


class DatabaseDuplicateError(DatabaseError):
    """Raised on UNIQUE constraint violations (MySQL errno 1062)."""

    def __init__(self, message: str = "Dữ liệu bị trùng lặp (vi phạm ràng buộc UNIQUE).", errno: int = 1062):
        super().__init__(message, status_code=409, errno=errno)


class DatabaseConstraintError(DatabaseError):
    """Raised on FK, NOT NULL, or CHECK constraint violations."""

    def __init__(self, message: str = "Dữ liệu không hợp lệ (vi phạm ràng buộc toàn vẹn).", errno: int | None = None):
        super().__init__(message, status_code=400, errno=errno)


class DatabaseTriggerError(DatabaseError):
    """Raised when a MySQL Trigger rejects an operation via SIGNAL SQLSTATE '45000'."""

    def __init__(self, message: str, errno: int = 1644):
        super().__init__(message, status_code=400, errno=errno)


_pool_lock = threading.Lock()
_pool: pooling.MySQLConnectionPool | None = None


def reset_pool() -> None:
    """Reset the cached connection pool (useful for tests or reconfig)."""
    global _pool
    with _pool_lock:
        _pool = None


def get_pool() -> pooling.MySQLConnectionPool:
    """Lazily initialize and return the MySQL connection pool."""
    global _pool
    if _pool is None:
        with _pool_lock:
            if _pool is None:
                try:
                    _pool = pooling.MySQLConnectionPool(
                        pool_name="podify_pool",
                        pool_size=Settings.DB_POOL_SIZE,
                        pool_reset_session=True,
                        host=Settings.DB_HOST,
                        port=Settings.DB_PORT,
                        database=Settings.DB_NAME,
                        user=Settings.DB_USER,
                        password=Settings.DB_PASSWORD,
                        charset="utf8mb4",
                        collation="utf8mb4_unicode_ci",
                        autocommit=False,
                    )
                except MySQLError as exc:
                    raise DatabaseUnavailableError(
                        f"Không thể kết nối MySQL ({Settings.DB_HOST}:{Settings.DB_PORT}/{Settings.DB_NAME}): {exc.msg}"
                    ) from exc
    return _pool


def translate_mysql_error(exc: MySQLError) -> DatabaseError:
    """Map MySQL driver error numbers to semantic HTTP-friendly exceptions."""
    errno = getattr(exc, "errno", None)
    msg = getattr(exc, "msg", str(exc))

    if errno == 1062:
        return DatabaseDuplicateError(f"Dữ liệu đã tồn tại: {msg}", errno=errno)
    if errno == 1644:
        return DatabaseTriggerError(msg, errno=errno)
    if errno in (1048, 1216, 1217, 1451, 1452, 3819, 1264, 1265, 1366):
        return DatabaseConstraintError(f"Vi phạm ràng buộc dữ liệu: {msg}", errno=errno)
    if errno in (2002, 2003, 2005, 2006, 2013, 1045, 1049):
        return DatabaseUnavailableError(f"Lỗi kết nối MySQL ({errno}): {msg}")
    return DatabaseError(f"Lỗi truy vấn cơ sở dữ liệu ({errno}): {msg}", status_code=500, errno=errno)


def _acquire_connection():
    """Acquire a connection from the pool, retrying briefly if all slots are momentarily busy."""
    last_exc = None
    for attempt in range(8):
        try:
            return get_pool().get_connection()
        except pooling.PoolError as exc:
            last_exc = exc
            time.sleep(0.05 * (attempt + 1))
    raise translate_mysql_error(last_exc) from last_exc


@contextmanager
def get_cursor(dictionary: bool = True, commit: bool = False):
    """Yield a MySQL cursor from the pool and handle commit/rollback/cleanup."""
    conn = None
    cursor = None
    try:
        conn = _acquire_connection()
        cursor = conn.cursor(dictionary=dictionary)
        yield cursor
        if commit:
            conn.commit()
    except MySQLError as exc:
        if conn is not None:
            try:
                conn.rollback()
            except MySQLError:
                pass
        raise translate_mysql_error(exc) from exc
    except Exception:
        if conn is not None:
            try:
                conn.rollback()
            except MySQLError:
                pass
        raise
    finally:
        if cursor is not None:
            cursor.close()
        if conn is not None:
            conn.close()


def fetch_all(sql: str, params: tuple | list | dict | None = None) -> list[dict]:
    """Execute a SELECT query and return all rows as dicts."""
    with get_cursor(dictionary=True, commit=False) as cur:
        cur.execute(sql, params or ())
        return cur.fetchall()


def fetch_one(sql: str, params: tuple | list | dict | None = None) -> dict | None:
    """Execute a SELECT query and return the first row or None."""
    with get_cursor(dictionary=True, commit=False) as cur:
        cur.execute(sql, params or ())
        return cur.fetchone()


def execute(sql: str, params: tuple | list | dict | None = None) -> tuple[int, int]:
    """Execute an INSERT/UPDATE/DELETE statement and return (rowcount, lastrowid)."""
    with get_cursor(dictionary=False, commit=True) as cur:
        cur.execute(sql, params or ())
        return cur.rowcount, cur.lastrowid


def check_health() -> dict:
    """Verify MySQL connectivity and report table count in podify_db."""
    row = fetch_one(
        """
        SELECT DATABASE() AS db_name,
               VERSION() AS mysql_version,
               (SELECT COUNT(*) FROM information_schema.tables
                WHERE table_schema = DATABASE()) AS table_count
        """
    )
    return row or {}
