"""Database Schema, Constraints, Triggers, Seed, and Queries (Q1-Q8) Test Suite."""

import os
import re
import sys
import unittest

ROOT_DIR = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
BACKEND_DIR = os.path.join(ROOT_DIR, "backend")
if BACKEND_DIR not in sys.path:
    sys.path.insert(0, BACKEND_DIR)

from config.settings import Settings
from init_db import split_sql_statements

EXPECTED_TABLES = [
    "NguoiDung",
    "NhaSangTao",
    "KenhPodcast",
    "TapPodcast",
    "TheoDoi",
    "LichSuNghe",
    "DanhGia",
    "UngHo",
    "QuangCao",
    "HopDongQC",
    "ViTriQC",
    "DoanhThuQC",
]


def _read(rel_path: str) -> str:
    with open(os.path.join(ROOT_DIR, rel_path), "r", encoding="utf-8") as f:
        return f.read()


class TestDatabaseArtifactsStatic(unittest.TestCase):
    """Static verification of SQL scripts, schema completeness, and Q1..Q8."""

    def test_full_schema_defines_all_12_tables(self):
        schema_sql = _read("database/schema/full_schema.sql")
        created = re.findall(r"CREATE TABLE\s+(\w+)\s*\(", schema_sql, flags=re.IGNORECASE)
        self.assertEqual(created, EXPECTED_TABLES)

    def test_seed_scripts_populate_all_tables(self):
        seed_sql = _read("database/seed/full_seed.sql")
        inserted = re.findall(r"INSERT INTO\s+(\w+)", seed_sql, flags=re.IGNORECASE)
        self.assertEqual(set(inserted), set(EXPECTED_TABLES))

    def test_all_8_queries_and_trigger_exist(self):
        q_sql = _read("database/queries/queries.sql")
        self.assertIn("USE podify_db", q_sql)
        self.assertIn("TRG_ViTriQC_KiemTra_BI", q_sql)
        select_count = len(re.findall(r"\bSELECT\b", q_sql, flags=re.IGNORECASE))
        self.assertGreaterEqual(select_count, 8)

    def test_erd_files_exist(self):
        self.assertTrue(os.path.isfile(os.path.join(ROOT_DIR, "database", "erd", "BTL_DB.drawio")))
        self.assertTrue(os.path.isfile(os.path.join(ROOT_DIR, "database", "erd", "BTL_DB.drawio.png")))


@unittest.skipUnless(
    os.getenv("TEST_MYSQL") == "1" and bool(Settings.DB_PASSWORD or os.getenv("ALLOW_EMPTY_DB_PASS") == "1"),
    "Skipped live MySQL execution (set TEST_MYSQL=1 with configured .env to run against MySQL 8.0)",
)
class TestLiveMySQLDatabase(unittest.TestCase):
    """Live MySQL 8.0 verification of schema, constraints, triggers, and Q1..Q8."""

    @classmethod
    def setUpClass(cls):
        import mysql.connector
        from init_db import init_database

        init_database(with_seed=True)
        cls.conn = mysql.connector.connect(
            host=Settings.DB_HOST,
            port=Settings.DB_PORT,
            database=Settings.DB_NAME,
            user=Settings.DB_USER,
            password=Settings.DB_PASSWORD,
            charset="utf8mb4",
            collation="utf8mb4_unicode_ci",
        )

    @classmethod
    def tearDownClass(cls):
        if getattr(cls, "conn", None):
            cls.conn.close()

    def setUp(self):
        self.conn.ping(reconnect=True, attempts=2, delay=0)

    def test_12_tables_created(self):
        cur = self.conn.cursor()
        cur.execute("SHOW TABLES")
        tables = {row[0].lower() for row in cur.fetchall()}
        cur.close()
        for t in EXPECTED_TABLES:
            self.assertIn(t.lower(), tables)

    def test_unique_and_check_constraints(self):
        import mysql.connector

        cur = self.conn.cursor()
        # Duplicate subscription (ND0007, KP0001 already exists in seed)
        with self.assertRaises(mysql.connector.Error) as ctx1:
            cur.execute("INSERT INTO TheoDoi (ma_theo_doi, ma_nguoi_dung, ma_kenh) VALUES ('TD9999', 'ND0007', 'KP0001')")
        self.assertEqual(ctx1.exception.errno, 1062)
        self.conn.rollback()

        # Invalid rating score (CHECK 1..5)
        with self.assertRaises(mysql.connector.Error) as ctx2:
            cur.execute("INSERT INTO DanhGia (ma_danh_gia, ma_nguoi_dung, ma_tap, so_sao) VALUES ('DG9999', 'ND0020', 'EP0001', 6)")
        self.assertEqual(ctx2.exception.errno, 3819)
        self.conn.rollback()
        cur.close()

    def test_queries_q1_to_q8_return_expected_results(self):
        cur = self.conn.cursor(dictionary=True)
        result_sets = []
        for stmt in split_sql_statements(_read("database/queries/queries.sql")):
            cur.execute(stmt)
            if cur.with_rows:
                result_sets.append(cur.fetchall())
        cur.close()

        self.assertEqual(len(result_sets), 8)
        self.assertEqual([len(rows) for rows in result_sets], [5, 3, 10, 2, 7, 11, 11, 24])


if __name__ == "__main__":
    unittest.main(verbosity=2)
