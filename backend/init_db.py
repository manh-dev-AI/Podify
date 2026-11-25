"""Initialize or reset the Podify MySQL database (schema and seed data)."""

import os
import sys
import mysql.connector

from config.settings import Settings

ROOT_DIR = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
SCHEMA_FILE = os.path.join(ROOT_DIR, "database", "schema", "full_schema.sql")
SEED_FILE = os.path.join(ROOT_DIR, "database", "seed", "full_seed.sql")


def _strip_inline_comment(line: str) -> str:
    """Remove trailing `-- comment` outside single-quoted string literals."""
    in_single_quote = False
    i = 0
    while i < len(line):
        ch = line[i]
        if ch == "'" and (i == 0 or line[i - 1] != "\\"):
            in_single_quote = not in_single_quote
        elif not in_single_quote and line[i : i + 2] == "--":
            if i == 0 or line[i - 1].isspace():
                return line[:i].rstrip()
        i += 1
    return line.rstrip()


def split_sql_statements(sql_text: str) -> list[str]:
    """Split a MySQL script (supporting DELIMITER blocks and inline comments) into statements."""
    statements: list[str] = []
    delimiter = ";"
    buffer: list[str] = []

    for raw_line in sql_text.splitlines():
        cleaned = _strip_inline_comment(raw_line)
        stripped = cleaned.strip()
        if not stripped:
            continue
        if stripped.upper().startswith("DELIMITER "):
            delimiter = stripped.split(None, 1)[1].strip()
            continue

        buffer.append(cleaned)
        joined = "\n".join(buffer).rstrip()
        if joined.endswith(delimiter):
            stmt = joined[: -len(delimiter)].strip()
            if stmt:
                statements.append(stmt)
            buffer = []

    leftover = "\n".join(buffer).strip()
    if leftover:
        statements.append(leftover)
    return statements


def run_sql_file(cursor, path: str) -> int:
    """Execute all statements in a SQL file using an active MySQL cursor."""
    with open(path, "r", encoding="utf-8") as f:
        statements = split_sql_statements(f.read())
    for stmt in statements:
        cursor.execute(stmt)
        if cursor.with_rows:
            cursor.fetchall()
    return len(statements)


def init_database(with_seed: bool = True) -> None:
    """Connect to MySQL server and apply schema and optional seed data."""
    conn = mysql.connector.connect(
        host=Settings.DB_HOST,
        port=Settings.DB_PORT,
        user=Settings.DB_USER,
        password=Settings.DB_PASSWORD,
        charset="utf8mb4",
        collation="utf8mb4_unicode_ci",
        autocommit=True,
    )
    try:
        cur = conn.cursor()
        n_schema = run_sql_file(cur, SCHEMA_FILE)
        print(f"[OK] Schema applied ({n_schema} statements) from {SCHEMA_FILE}")

        if with_seed:
            n_seed = run_sql_file(cur, SEED_FILE)
            print(f"[OK] Seed data applied ({n_seed} statements) from {SEED_FILE}")
        cur.close()
    finally:
        conn.close()


if __name__ == "__main__":
    seed_flag = "--no-seed" not in sys.argv
    init_database(with_seed=seed_flag)
