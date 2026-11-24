"""Cross-module Integration Tests across Content, Listening, and Analytics."""

import os
import sys
import unittest
from unittest.mock import patch

ROOT_DIR = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
BACKEND_DIR = os.path.join(ROOT_DIR, "backend")
if BACKEND_DIR not in sys.path:
    sys.path.insert(0, BACKEND_DIR)

from app import create_app
from common.auth import create_access_token


class TestCrossModuleIntegration(unittest.TestCase):
    """Verify end-to-end API flow across Content -> Listening -> Ads & Donations."""

    def setUp(self):
        self.app = create_app()
        self.app.testing = True
        self.client = self.app.test_client()
        self.creator_token = create_access_token("ND0001", "creator")
        self.user_token = create_access_token("ND0007", "user")

    def test_cross_module_flow_mocked(self):
        creator = {
            "user_id": "ND0001",
            "username": "manh_trithuc",
            "role": "creator",
            "creator_id": "NST0001",
            "creator_display_name": "Mạnh Tri Thức",
        }
        listener = {
            "user_id": "ND0007",
            "username": "nam_nghe",
            "role": "user",
            "creator_id": None,
        }

        # 1. Creator creates an episode in Content module
        with patch("common.auth.load_user_with_creator", return_value=creator), patch(
            "config.db.fetch_one",
            side_effect=[{"channel_id": "KP0001", "creator_id": "NST0001"}, {"episode_id": "EP0030", "title": "New Ep"}],
        ), patch("config.db.next_id", return_value="EP0030"), patch("config.db.execute", return_value=(1, None)):
            res_ep = self.client.post(
                "/api/content/episodes",
                headers={"Authorization": f"Bearer {self.creator_token}"},
                json={
                    "channel_id": "KP0001",
                    "title": "New Ep",
                    "audio_url": "/assets/audio/sample_1.mp3",
                    "duration_seconds": 1500,
                },
            )
            self.assertEqual(res_ep.status_code, 201)

        # 2. Listener saves progress in Listening module
        with patch("common.auth.load_user_with_creator", return_value=listener), patch(
            "config.db.fetch_one",
            side_effect=[
                {"episode_id": "EP0030", "duration_seconds": 1500},
                {"history_id": "LS0056", "episode_id": "EP0030", "last_position_seconds": 450, "is_completed": 0},
            ],
        ), patch("config.db.next_id", return_value="LS0056"), patch("config.db.execute", return_value=(1, None)):
            res_prog = self.client.post(
                "/api/listening/progress",
                headers={"Authorization": f"Bearer {self.user_token}"},
                json={"episode_id": "EP0030", "position_seconds": 450, "new_session": True},
            )
            self.assertEqual(res_prog.status_code, 201)

        # 3. Listener donates to Creator in Analytics module
        with patch("common.auth.load_user_with_creator", return_value=listener), patch(
            "config.db.fetch_one",
            return_value={"donation_id": "UH0016", "amount": 100000.0, "creator_id": "NST0001"},
        ), patch("config.db.next_id", return_value="UH0016"), patch("config.db.execute", return_value=(1, None)):
            res_don = self.client.post(
                "/api/analytics/donations",
                headers={"Authorization": f"Bearer {self.user_token}"},
                json={"creator_id": "NST0001", "episode_id": "EP0030", "amount": 100000, "message": "Great episode!"},
            )
            self.assertEqual(res_don.status_code, 201)


@unittest.skipUnless(
    os.getenv("TEST_MYSQL") == "1",
    "Skipped live cross-module MySQL test (set TEST_MYSQL=1 with configured .env to run)",
)
class TestCrossModuleLiveMySQL(unittest.TestCase):
    """End-to-end live integration test against MySQL 8.0."""

    @classmethod
    def setUpClass(cls):
        from init_db import init_database

        init_database(with_seed=True)
        cls.app = create_app()
        cls.client = cls.app.test_client()

    def test_full_user_and_creator_journey_live(self):
        login_c = self.client.post("/api/content/auth/login", json={"identifier": "manh_trithuc", "password": "123456"})
        self.assertEqual(login_c.status_code, 200)
        c_token = login_c.get_json()["data"]["token"]

        ch_res = self.client.post(
            "/api/content/channels",
            headers={"Authorization": f"Bearer {c_token}"},
            json={"title": "Integration Test Channel", "category": "Công nghệ"},
        )
        self.assertEqual(ch_res.status_code, 201)
        ch_id = ch_res.get_json()["data"]["channel_id"]

        ep_res = self.client.post(
            "/api/content/episodes",
            headers={"Authorization": f"Bearer {c_token}"},
            json={
                "channel_id": ch_id,
                "title": "Integration Ep",
                "audio_url": "/assets/audio/sample_1.mp3",
                "duration_seconds": 1000,
            },
        )
        self.assertEqual(ep_res.status_code, 201)
        ep_id = ep_res.get_json()["data"]["episode_id"]

        login_u = self.client.post("/api/content/auth/login", json={"identifier": "nam_nghe", "password": "123456"})
        self.assertEqual(login_u.status_code, 200)
        u_token = login_u.get_json()["data"]["token"]

        self.assertEqual(
            self.client.post(
                "/api/listening/subscriptions", headers={"Authorization": f"Bearer {u_token}"}, json={"channel_id": ch_id}
            ).status_code,
            201,
        )
        self.assertEqual(
            self.client.post(
                "/api/listening/progress",
                headers={"Authorization": f"Bearer {u_token}"},
                json={"episode_id": ep_id, "position_seconds": 300, "new_session": True},
            ).status_code,
            201,
        )
        self.assertEqual(
            self.client.post(
                "/api/listening/ratings",
                headers={"Authorization": f"Bearer {u_token}"},
                json={"episode_id": ep_id, "score": 5},
            ).status_code,
            200,
        )
        self.assertEqual(
            self.client.post(
                "/api/analytics/donations",
                headers={"Authorization": f"Bearer {u_token}"},
                json={"creator_id": "NST0001", "episode_id": ep_id, "amount": 50000},
            ).status_code,
            201,
        )


if __name__ == "__main__":
    unittest.main(verbosity=2)
