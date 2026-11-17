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
    "Users",
    "Creators",
    "PodcastChannels",
    "Episodes",
    "Subscriptions",
    "ListeningHistory",
    "Ratings",
    "Advertisements",
    "AdContracts",
    "AdSlots",
    "AdRevenue",
    "Donations",
]


def _read(rel_path: str) -> str:
    with open(os.path.join(ROOT_DIR, rel_path), "r", encoding="utf-8") as f:
        return f.read()


class TestDatabaseArtifactsStatic(unittest.TestCase):
    """Static verification of SQL scripts, schema completeness, triggers, and Q1..Q8."""

    def test_full_schema_defines_all_12_tables(self):
        schema_sql = _read("database/schema/full_schema.sql")
        created = re.findall(r"CREATE TABLE\s+(\w+)\s*\(", schema_sql, flags=re.IGNORECASE)
        self.assertEqual(created, EXPECTED_TABLES)

    def test_modular_schemas_match_12_tables(self):
        s1 = _read("database/schema/01_users_content.sql")
        s2 = _read("database/schema/02_listening.sql")
        s3 = _read("database/schema/03_advertisement.sql")
        combined = "\n".join([s1, s2, s3])
        created = re.findall(r"CREATE TABLE\s+(\w+)\s*\(", combined, flags=re.IGNORECASE)
        self.assertEqual(created, EXPECTED_TABLES)

    def test_triggers_script_contains_all_three_triggers(self):
        trg_sql = _read("database/triggers/01_ad_contract_limit.sql")
        triggers = re.findall(r"CREATE TRIGGER\s+(\w+)", trg_sql, flags=re.IGNORECASE)
        self.assertEqual(
            triggers,
            [
                "TRG_AdSlots_Limit_Contracts_BI",
                "TRG_AdSlots_Limit_Contracts_BU",
                "TRG_Episodes_Duration_Limit_BU",
            ],
        )
        stmts = split_sql_statements(trg_sql)
        self.assertGreaterEqual(len(stmts), 7)  # USE + 3 DROPs + 3 CREATE TRIGGERs

    def test_seed_scripts_populate_all_tables(self):
        seed_sql = _read("database/seed/full_seed.sql")
        inserted = re.findall(r"INSERT INTO\s+(\w+)", seed_sql, flags=re.IGNORECASE)
        self.assertEqual(inserted, EXPECTED_TABLES)

    def test_all_8_queries_exist_and_non_empty(self):
        for i in range(1, 9):
            q_sql = _read(f"database/queries/Q{i}.sql")
            self.assertIn("SELECT", q_sql.upper(), f"Q{i}.sql missing SELECT")
            self.assertIn("USE podify_db", q_sql)

    def test_erd_files_exist(self):
        self.assertTrue(os.path.isfile(os.path.join(ROOT_DIR, "database", "erd", "podify_erd.png")))
        self.assertTrue(os.path.isfile(os.path.join(ROOT_DIR, "database", "erd", "podify_erd.svg")))


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

    def test_trigger_blocks_4th_contract_on_under_20m_episode(self):
        import mysql.connector

        cur = self.conn.cursor()
        # Episode 3 is 600s (< 20m) and already has contracts 1, 2, 3 in seed
        with self.assertRaises(mysql.connector.Error) as ctx:
            cur.execute(
                "INSERT INTO AdSlots (contract_id, episode_id, slot_position, start_offset_seconds) VALUES (4, 3, 'mid-roll', 150)"
            )
        self.assertEqual(ctx.exception.errno, 1644)
        self.conn.rollback()
        cur.close()

    def test_trigger_blocks_shrinking_episode_duration_with_4_contracts(self):
        import mysql.connector

        cur = self.conn.cursor()
        # Episode 4 is 2400s and has 4 contracts attached in seed
        with self.assertRaises(mysql.connector.Error) as ctx:
            cur.execute("UPDATE Episodes SET duration_seconds = 900 WHERE episode_id = 4")
        self.assertEqual(ctx.exception.errno, 1644)
        self.conn.rollback()
        cur.close()

    def test_unique_and_check_constraints(self):
        import mysql.connector

        cur = self.conn.cursor()
        # Duplicate subscription (user 4, channel 1 already exists in seed)
        with self.assertRaises(mysql.connector.Error) as ctx1:
            cur.execute("INSERT INTO Subscriptions (user_id, channel_id) VALUES (4, 1)")
        self.assertEqual(ctx1.exception.errno, 1062)
        self.conn.rollback()

        # Invalid rating score (CHECK 1..5)
        with self.assertRaises(mysql.connector.Error) as ctx2:
            cur.execute("INSERT INTO Ratings (user_id, episode_id, score) VALUES (3, 1, 6)")
        self.assertEqual(ctx2.exception.errno, 3819)
        self.conn.rollback()
        cur.close()

    def test_queries_q1_to_q8_return_expected_results(self):
        cur = self.conn.cursor(dictionary=True)

        def run_q(path):
            rows = []
            for stmt in split_sql_statements(_read(path)):
                cur.execute(stmt)
                if cur.with_rows:
                    rows = cur.fetchall()
            return rows

        q1 = run_q("database/queries/Q1.sql")
        self.assertEqual([r["episode_id"] for r in q1], [1, 2])

        q2 = run_q("database/queries/Q2.sql")
        self.assertEqual(len(q2), 3)

        q3 = run_q("database/queries/Q3.sql")
        self.assertEqual(len(q3), 3)

        q4 = run_q("database/queries/Q4.sql")
        self.assertEqual([r["channel_id"] for r in q4], [3])

        q5 = run_q("database/queries/Q5.sql")
        ep4 = next(r for r in q5 if r["episode_id"] == 4)
        self.assertEqual(ep4["listen_count"], 0)

        q6 = run_q("database/queries/Q6.sql")
        self.assertGreaterEqual(len(q6), 3)

        q7 = run_q("database/queries/Q7.sql")
        self.assertEqual([r["username"] for r in q7], ["le_c"])

        q8 = run_q("database/queries/Q8.sql")
        self.assertGreaterEqual(len(q8), 6)
        cur.close()


if __name__ == "__main__":
    unittest.main(verbosity=2)
