"""API Route Unit & Contract Tests for Podify Flask Backend."""

import os
import sys
import unittest
from unittest.mock import patch
from werkzeug.security import generate_password_hash

ROOT_DIR = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
BACKEND_DIR = os.path.join(ROOT_DIR, "backend")
if BACKEND_DIR not in sys.path:
    sys.path.insert(0, BACKEND_DIR)

from app import create_app
from common.auth import create_access_token
from config.db import DatabaseDuplicateError, DatabaseTriggerError


class TestPodifyAPIEndpoints(unittest.TestCase):
    """Verify Flask API routes, auth guards, DB error mapping, and Q1..Q8 endpoints."""

    def setUp(self):
        self.app = create_app()
        self.app.testing = True
        self.client = self.app.test_client()

        self.creator_user = {
            "user_id": 1,
            "username": "nguyenvan_a",
            "email": "a@example.com",
            "full_name": "Nguyễn Văn A",
            "role": "creator",
            "avatar_url": None,
            "created_at": "2026-01-17T00:00:00",
            "creator_id": 1,
            "creator_display_name": "Tech Talk VN",
            "creator_bio": "Bio",
            "creator_verified": 1,
        }
        self.normal_user = {
            "user_id": 4,
            "username": "pham_d",
            "email": "d@example.com",
            "full_name": "Phạm Minh D",
            "role": "user",
            "avatar_url": None,
            "created_at": "2026-09-17T00:00:00",
            "creator_id": None,
            "creator_display_name": None,
            "creator_bio": None,
            "creator_verified": None,
        }
        self.creator_token = create_access_token(1, "creator")
        self.user_token = create_access_token(4, "user")

    def test_health_and_frontend_serving(self):
        with self.client.get("/") as res_index:
            self.assertEqual(res_index.status_code, 200)
            self.assertIn(b"Podify", res_index.data)

        with self.client.get("/api/health") as res_health:
            self.assertEqual(res_health.status_code, 200)
            self.assertEqual(res_health.get_json()["status"], "ok")

    def test_login_success_and_invalid_password(self):
        pw_hash = generate_password_hash("123456", method="pbkdf2:sha256")
        with patch("config.db.fetch_one", return_value={"user_id": 1, "password_hash": pw_hash, "role": "creator"}), patch(
            "modules.content.routes.load_user_with_creator", return_value=self.creator_user
        ):
            ok_res = self.client.post("/api/content/auth/login", json={"identifier": "nguyenvan_a", "password": "123456"})
            self.assertEqual(ok_res.status_code, 200)
            self.assertTrue(ok_res.get_json()["ok"])
            self.assertIn("token", ok_res.get_json()["data"])

            bad_res = self.client.post("/api/content/auth/login", json={"identifier": "nguyenvan_a", "password": "wrong"})
            self.assertEqual(bad_res.status_code, 401)

    def test_register_validation_and_duplicate_checks(self):
        # Invalid username format
        r1 = self.client.post(
            "/api/content/auth/register",
            json={"username": "a b", "email": "x@example.com", "password": "password1", "full_name": "Test"},
        )
        self.assertEqual(r1.status_code, 400)

        # Password mismatch
        r2 = self.client.post(
            "/api/content/auth/register",
            json={
                "username": "linh_test",
                "email": "linh@example.com",
                "password": "password1",
                "confirm_password": "password2",
                "full_name": "Linh",
            },
        )
        self.assertEqual(r2.status_code, 400)
        self.assertEqual(r2.get_json()["code"], "PASSWORD_MISMATCH")

        # Duplicate username returns 409
        with patch("config.db.fetch_one", return_value={"username": "linh_test", "email": "other@example.com"}):
            r3 = self.client.post(
                "/api/content/auth/register",
                json={
                    "username": "linh_test",
                    "email": "linh@example.com",
                    "password": "password1",
                    "confirm_password": "password1",
                    "full_name": "Linh",
                },
            )
            self.assertEqual(r3.status_code, 409)
            self.assertEqual(r3.get_json()["code"], "USERNAME_EXISTS")

    def test_auth_guards_and_role_authorization(self):
        res_unauth = self.client.post("/api/listening/subscriptions", json={"channel_id": 1})
        self.assertEqual(res_unauth.status_code, 401)

        with patch("common.auth.load_user_with_creator", return_value=self.normal_user):
            res_forbidden = self.client.post(
                "/api/content/channels",
                headers={"Authorization": f"Bearer {self.user_token}"},
                json={"title": "Test", "category": "Tech"},
            )
            self.assertEqual(res_forbidden.status_code, 403)

    def test_duplicate_subscription_returns_409(self):
        with patch("common.auth.load_user_with_creator", return_value=self.normal_user), patch(
            "config.db.fetch_one", return_value={"channel_id": 1, "title": "Lập Trình Không Khó"}
        ), patch(
            "config.db.execute",
            side_effect=DatabaseDuplicateError("Duplicate entry '4-1' for key 'UQ_Subscriptions_User_Channel'"),
        ):
            res = self.client.post(
                "/api/listening/subscriptions",
                headers={"Authorization": f"Bearer {self.user_token}"},
                json={"channel_id": 1},
            )
            self.assertEqual(res.status_code, 409)
            self.assertEqual(res.get_json()["code"], "DB_DUPLICATE_ENTRY")

    def test_rating_score_validation(self):
        with patch("common.auth.load_user_with_creator", return_value=self.normal_user):
            res = self.client.post(
                "/api/listening/ratings",
                headers={"Authorization": f"Bearer {self.user_token}"},
                json={"episode_id": 1, "score": 6},
            )
            self.assertEqual(res.status_code, 400)

    def test_ad_slot_limit_blocks_4th_contract_under_20m(self):
        with patch("common.auth.load_user_with_creator", return_value=self.creator_user), patch(
            "config.db.fetch_one",
            side_effect=[
                {"duration_seconds": 600, "creator_id": 1},
                {"contract_id": 4, "creator_id": 1},
                {"distinct_contracts": 3, "already_attached": 0},
            ],
        ):
            res = self.client.post(
                "/api/analytics/slots",
                headers={"Authorization": f"Bearer {self.creator_token}"},
                json={"contract_id": 4, "episode_id": 3, "slot_position": "mid-roll", "start_offset_seconds": 120},
            )
            self.assertEqual(res.status_code, 400)
            body = res.get_json()
            self.assertIn("tối đa 3 hợp đồng", body["error"])

    def test_update_episode_blocks_shrinking_duration_with_over_3_contracts(self):
        with patch("common.auth.load_user_with_creator", return_value=self.creator_user), patch(
            "config.db.fetch_one",
            side_effect=[
                {
                    "episode_id": 4,
                    "title": "Ep 4",
                    "description": None,
                    "audio_url": "/assets/audio/sample_4.mp3",
                    "duration_seconds": 2400,
                    "status": "published",
                    "creator_id": 1,
                },
                {"distinct_contracts": 4},
            ],
        ):
            res = self.client.put(
                "/api/content/episodes/4",
                headers={"Authorization": f"Bearer {self.creator_token}"},
                json={"duration_seconds": 900},
            )
            self.assertEqual(res.status_code, 400)
            self.assertIn("hơn 3 hợp đồng quảng cáo", res.get_json()["error"])

    def test_query_runner_endpoints_q1_to_q8(self):
        res_list = self.client.get("/api/analytics/reports/queries")
        self.assertEqual(res_list.status_code, 200)
        self.assertEqual(len(res_list.get_json()["data"]), 8)

        with patch("config.db.fetch_all", return_value=[{"episode_id": 1}]):
            for qid in ("Q1", "Q2", "Q3", "Q4", "Q5", "Q6", "Q7", "Q8"):
                res_q = self.client.get(f"/api/analytics/reports/queries/{qid}")
                self.assertEqual(res_q.status_code, 200)
                self.assertEqual(res_q.get_json()["data"]["id"], qid)

        res_bad = self.client.get("/api/analytics/reports/queries/Q99")
        self.assertEqual(res_bad.status_code, 404)


if __name__ == "__main__":
    unittest.main(verbosity=2)
