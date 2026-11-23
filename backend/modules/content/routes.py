"""Module 01: Content Management RESTful API Blueprint."""

import re
from flask import Blueprint, request
from werkzeug.security import check_password_hash, generate_password_hash

from common.auth import (
    create_access_token,
    get_current_user,
    get_optional_user,
    load_user_with_creator,
    login_required,
    roles_required,
)
from common.errors import AppError
from common.response import success
from config import db

content_bp = Blueprint("content", __name__, url_prefix="/api/content")


def _json_body() -> dict:
    data = request.get_json(silent=True)
    if not isinstance(data, dict):
        raise AppError("Request body phải là JSON hợp lệ.", status_code=400, code="INVALID_JSON")
    return data


def _require_fields(data: dict, *fields: str) -> None:
    missing = [f for f in fields if data.get(f) is None or str(data.get(f)).strip() == ""]
    if missing:
        raise AppError(
            f"Thiếu thông tin bắt buộc: {', '.join(missing)}.",
            status_code=400,
            code="MISSING_FIELDS",
        )


@content_bp.post("/auth/register")
def register():
    """Register a new user (and optionally initialize a Creator profile)."""
    data = _json_body()
    _require_fields(data, "username", "email", "password", "full_name")

    username = str(data["username"]).strip()
    email = str(data["email"]).strip().lower()
    password = str(data["password"])
    confirm_password = data.get("confirm_password")
    full_name = str(data["full_name"]).strip()
    role = str(data.get("role", "user")).strip().lower()

    if not re.match(r"^[a-zA-Z0-9_]{3,50}$", username):
        raise AppError(
            "Tên đăng nhập phải dài 3–50 ký tự, chỉ gồm chữ cái, số và dấu gạch dưới (_).",
            status_code=400,
            code="INVALID_USERNAME",
        )
    if not re.match(r"^[^@\s]+@[^@\s]+\.[^@\s]+$", email):
        raise AppError("Địa chỉ email không đúng định dạng.", status_code=400, code="INVALID_EMAIL")
    if role not in ("user", "creator"):
        raise AppError("Vai trò đăng ký chỉ hỗ trợ 'user' hoặc 'creator'.", status_code=400)
    if len(password) < 6:
        raise AppError("Mật khẩu phải có ít nhất 6 ký tự.", status_code=400)
    if confirm_password is not None and password != str(confirm_password):
        raise AppError("Mật khẩu xác nhận không khớp.", status_code=400, code="PASSWORD_MISMATCH")

    existing_user = db.fetch_one(
        "SELECT username, email FROM Users WHERE username = %s OR email = %s",
        (username, email),
    )
    if existing_user:
        if existing_user["username"].lower() == username.lower():
            raise AppError("Tên đăng nhập này đã được sử dụng.", status_code=409, code="USERNAME_EXISTS")
        raise AppError("Email này đã được đăng ký tài khoản khác.", status_code=409, code="EMAIL_EXISTS")

    password_hash = generate_password_hash(password, method="pbkdf2:sha256")
    display_name = str(data.get("display_name") or full_name).strip()
    bio = str(data.get("bio") or "").strip() or None

    with db.get_cursor(dictionary=True, commit=True) as cur:
        cur.execute(
            """
            INSERT INTO Users (username, email, password_hash, full_name, role, avatar_url)
            VALUES (%s, %s, %s, %s, %s, %s)
            """,
            (username, email, password_hash, full_name, role, data.get("avatar_url")),
        )
        user_id = cur.lastrowid

        if role == "creator":
            cur.execute(
                """
                INSERT INTO Creators (user_id, display_name, bio, verified)
                VALUES (%s, %s, %s, FALSE)
                """,
                (user_id, display_name, bio),
            )

    user = load_user_with_creator(user_id)
    token = create_access_token(user_id, user["role"])
    return success({"token": token, "user": user}, message="Đăng ký tài khoản thành công.", status=201)


@content_bp.post("/auth/login")
def login():
    """Authenticate a user by username or email and return a Bearer token."""
    data = _json_body()
    _require_fields(data, "identifier", "password")
    identifier = str(data["identifier"]).strip()
    password = str(data["password"])

    row = db.fetch_one(
        """
        SELECT user_id, password_hash, role
        FROM Users
        WHERE username = %s OR email = %s
        """,
        (identifier, identifier.lower()),
    )
    if not row or not check_password_hash(row["password_hash"], password):
        raise AppError("Tên đăng nhập/email hoặc mật khẩu không đúng.", status_code=401, code="INVALID_CREDENTIALS")

    user = load_user_with_creator(row["user_id"])
    token = create_access_token(row["user_id"], row["role"])
    return success({"token": token, "user": user}, message="Đăng nhập thành công.")


@content_bp.get("/auth/me")
@login_required
def me():
    """Return the currently authenticated user's profile."""
    return success(get_current_user())


@content_bp.get("/users/demo")
def list_demo_users():
    """Return safe public account summaries for the UI account switcher."""
    rows = db.fetch_all(
        """
        SELECT u.user_id, u.username, u.full_name, u.role,
               c.creator_id, c.display_name AS creator_display_name
        FROM Users u
        LEFT JOIN Creators c ON u.user_id = c.user_id
        ORDER BY u.user_id ASC
        """
    )
    return success(rows)


@content_bp.get("/creators")
def list_creators():
    """List creators along with channel, episode, and subscriber counts."""
    rows = db.fetch_all(
        """
        SELECT cr.creator_id, cr.user_id, cr.display_name, cr.bio, cr.verified, cr.created_at,
               u.username, u.full_name,
               COUNT(DISTINCT ch.channel_id) AS channel_count,
               COUNT(DISTINCT e.episode_id) AS episode_count,
               COUNT(DISTINCT s.subscription_id) AS subscriber_count
        FROM Creators cr
        INNER JOIN Users u ON cr.user_id = u.user_id
        LEFT JOIN PodcastChannels ch ON cr.creator_id = ch.creator_id
        LEFT JOIN Episodes e ON ch.channel_id = e.channel_id
        LEFT JOIN Subscriptions s ON ch.channel_id = s.channel_id
        GROUP BY cr.creator_id, cr.user_id, cr.display_name, cr.bio, cr.verified,
                 cr.created_at, u.username, u.full_name
        ORDER BY cr.creator_id ASC
        """
    )
    return success(rows)


@content_bp.put("/creators/profile")
@roles_required("creator", "admin")
def upsert_creator_profile():
    """Update or create the authenticated creator's profile."""
    user = get_current_user()
    data = _json_body()
    _require_fields(data, "display_name")
    display_name = str(data["display_name"]).strip()
    bio = str(data.get("bio") or "").strip() or None

    if user.get("creator_id"):
        db.execute(
            "UPDATE Creators SET display_name = %s, bio = %s WHERE creator_id = %s",
            (display_name, bio, user["creator_id"]),
        )
    else:
        db.execute(
            "INSERT INTO Creators (user_id, display_name, bio, verified) VALUES (%s, %s, %s, FALSE)",
            (user["user_id"], display_name, bio),
        )
    return success(load_user_with_creator(user["user_id"]), message="Cập nhật hồ sơ Creator thành công.")


@content_bp.get("/channels")
def list_channels():
    """List or search podcast channels with aggregated stats."""
    q = request.args.get("q", "").strip()
    category = request.args.get("category", "").strip()
    creator_id = request.args.get("creator_id", type=int)
    current = get_optional_user()
    current_uid = current["user_id"] if current else 0

    where_clauses = []
    params: list = [current_uid]

    if q:
        like = f"%{q}%"
        where_clauses.append("(ch.title LIKE %s OR ch.description LIKE %s OR cr.display_name LIKE %s)")
        params.extend([like, like, like])
    if category:
        where_clauses.append("ch.category = %s")
        params.append(category)
    if creator_id:
        where_clauses.append("ch.creator_id = %s")
        params.append(creator_id)

    where_sql = f"WHERE {' AND '.join(where_clauses)}" if where_clauses else ""

    rows = db.fetch_all(
        f"""
        SELECT ch.channel_id, ch.creator_id, ch.title, ch.description, ch.category,
               ch.cover_image_url, ch.created_at, ch.updated_at,
               cr.display_name AS creator_name, cr.verified AS creator_verified,
               COUNT(DISTINCT e.episode_id) AS episode_count,
               COUNT(DISTINCT s.subscription_id) AS subscriber_count,
               COALESCE(ROUND(AVG(r.score), 2), 0) AS avg_rating,
               COUNT(DISTINCT lh.history_id) AS total_listens,
               MAX(CASE WHEN s.user_id = %s THEN 1 ELSE 0 END) AS is_subscribed
        FROM PodcastChannels ch
        INNER JOIN Creators cr ON ch.creator_id = cr.creator_id
        LEFT JOIN Episodes e ON ch.channel_id = e.channel_id
        LEFT JOIN Subscriptions s ON ch.channel_id = s.channel_id
        LEFT JOIN Ratings r ON e.episode_id = r.episode_id
        LEFT JOIN ListeningHistory lh ON e.episode_id = lh.episode_id
        {where_sql}
        GROUP BY ch.channel_id, ch.creator_id, ch.title, ch.description, ch.category,
                 ch.cover_image_url, ch.created_at, ch.updated_at,
                 cr.display_name, cr.verified
        ORDER BY total_listens DESC, ch.channel_id ASC
        """,
        params,
    )
    return success(rows)


@content_bp.get("/channels/<int:channel_id>")
def get_channel(channel_id: int):
    """Get a single channel's details and its episodes."""
    current = get_optional_user()
    current_uid = current["user_id"] if current else 0

    channel = db.fetch_one(
        """
        SELECT ch.*, cr.display_name AS creator_name, cr.bio AS creator_bio, cr.verified AS creator_verified,
               COUNT(DISTINCT s.subscription_id) AS subscriber_count,
               COALESCE(ROUND(AVG(r.score), 2), 0) AS avg_rating,
               MAX(CASE WHEN s.user_id = %s THEN 1 ELSE 0 END) AS is_subscribed
        FROM PodcastChannels ch
        INNER JOIN Creators cr ON ch.creator_id = cr.creator_id
        LEFT JOIN Subscriptions s ON ch.channel_id = s.channel_id
        LEFT JOIN Episodes e ON ch.channel_id = e.channel_id
        LEFT JOIN Ratings r ON e.episode_id = r.episode_id
        WHERE ch.channel_id = %s
        GROUP BY ch.channel_id, cr.display_name, cr.bio, cr.verified
        """,
        (current_uid, channel_id),
    )
    if not channel:
        raise AppError("Không tìm thấy kênh Podcast.", status_code=404)

    episodes = db.fetch_all(
        """
        SELECT e.*,
               COUNT(DISTINCT lh.history_id) AS listen_count,
               COALESCE(ROUND(AVG(r.score), 2), 0) AS avg_rating,
               COUNT(DISTINCT sl.slot_id) AS ad_slot_count
        FROM Episodes e
        LEFT JOIN ListeningHistory lh ON e.episode_id = lh.episode_id
        LEFT JOIN Ratings r ON e.episode_id = r.episode_id
        LEFT JOIN AdSlots sl ON e.episode_id = sl.episode_id
        WHERE e.channel_id = %s
        GROUP BY e.episode_id
        ORDER BY e.published_at DESC, e.episode_id DESC
        """,
        (channel_id,),
    )
    channel["episodes"] = episodes
    return success(channel)


@content_bp.post("/channels")
@roles_required("creator", "admin")
def create_channel():
    """Create a new podcast channel owned by the authenticated creator."""
    user = get_current_user()
    if not user.get("creator_id"):
        raise AppError("Tài khoản chưa có hồ sơ Creator.", status_code=400)

    data = _json_body()
    _require_fields(data, "title", "category")
    _, channel_id = db.execute(
        """
        INSERT INTO PodcastChannels (creator_id, title, description, category, cover_image_url)
        VALUES (%s, %s, %s, %s, %s)
        """,
        (
            user["creator_id"],
            str(data["title"]).strip(),
            str(data.get("description") or "").strip() or None,
            str(data["category"]).strip(),
            data.get("cover_image_url"),
        ),
    )
    row = db.fetch_one("SELECT * FROM PodcastChannels WHERE channel_id = %s", (channel_id,))
    return success(row, message="Tạo kênh Podcast thành công.", status=201)


@content_bp.put("/channels/<int:channel_id>")
@roles_required("creator", "admin")
def update_channel(channel_id: int):
    """Update a podcast channel owned by the current creator (or admin)."""
    user = get_current_user()
    existing = db.fetch_one("SELECT * FROM PodcastChannels WHERE channel_id = %s", (channel_id,))
    if not existing:
        raise AppError("Không tìm thấy kênh Podcast.", status_code=404)
    if user["role"] != "admin" and existing["creator_id"] != user.get("creator_id"):
        raise AppError("Bạn không có quyền chỉnh sửa kênh này.", status_code=403)

    data = _json_body()
    title = str(data.get("title") or existing["title"]).strip()
    description = data.get("description", existing["description"])
    category = str(data.get("category") or existing["category"]).strip()
    cover_image_url = data.get("cover_image_url", existing["cover_image_url"])

    db.execute(
        """
        UPDATE PodcastChannels
        SET title = %s, description = %s, category = %s, cover_image_url = %s
        WHERE channel_id = %s
        """,
        (title, description, category, cover_image_url, channel_id),
    )
    updated = db.fetch_one("SELECT * FROM PodcastChannels WHERE channel_id = %s", (channel_id,))
    return success(updated, message="Cập nhật kênh Podcast thành công.")


@content_bp.delete("/channels/<int:channel_id>")
@roles_required("creator", "admin")
def delete_channel(channel_id: int):
    """Delete a podcast channel owned by the current creator (or admin)."""
    user = get_current_user()
    existing = db.fetch_one("SELECT * FROM PodcastChannels WHERE channel_id = %s", (channel_id,))
    if not existing:
        raise AppError("Không tìm thấy kênh Podcast.", status_code=404)
    if user["role"] != "admin" and existing["creator_id"] != user.get("creator_id"):
        raise AppError("Bạn không có quyền xóa kênh này.", status_code=403)

    db.execute("DELETE FROM PodcastChannels WHERE channel_id = %s", (channel_id,))
    return success({"deleted_channel_id": channel_id}, message="Đã xóa kênh Podcast.")


@content_bp.get("/episodes")
def list_episodes():
    """Search and filter episodes (supports duration range for Q1 and keyword search)."""
    q = request.args.get("q", "").strip()
    channel_id = request.args.get("channel_id", type=int)
    category = request.args.get("category", "").strip()
    status = request.args.get("status", "").strip()
    min_duration = request.args.get("min_duration", type=int)
    max_duration = request.args.get("max_duration", type=int)

    where_clauses = []
    params: list = []

    if q:
        like = f"%{q}%"
        where_clauses.append("(e.title LIKE %s OR e.description LIKE %s OR ch.title LIKE %s)")
        params.extend([like, like, like])
    if channel_id:
        where_clauses.append("e.channel_id = %s")
        params.append(channel_id)
    if category:
        where_clauses.append("ch.category = %s")
        params.append(category)
    if status:
        where_clauses.append("e.status = %s")
        params.append(status)
    if min_duration is not None:
        where_clauses.append("e.duration_seconds >= %s")
        params.append(min_duration)
    if max_duration is not None:
        where_clauses.append("e.duration_seconds <= %s")
        params.append(max_duration)

    where_sql = f"WHERE {' AND '.join(where_clauses)}" if where_clauses else ""

    rows = db.fetch_all(
        f"""
        SELECT e.episode_id, e.channel_id, e.title, e.description, e.audio_url,
               e.duration_seconds, SEC_TO_TIME(e.duration_seconds) AS duration_formatted,
               e.published_at, e.status, e.created_at,
               ch.title AS channel_title, ch.category, ch.creator_id,
               cr.display_name AS creator_name,
               COUNT(DISTINCT lh.history_id) AS listen_count,
               COALESCE(ROUND(AVG(r.score), 2), 0) AS avg_rating,
               COUNT(DISTINCT sl.contract_id) AS ad_contract_count
        FROM Episodes e
        INNER JOIN PodcastChannels ch ON e.channel_id = ch.channel_id
        INNER JOIN Creators cr ON ch.creator_id = cr.creator_id
        LEFT JOIN ListeningHistory lh ON e.episode_id = lh.episode_id
        LEFT JOIN Ratings r ON e.episode_id = r.episode_id
        LEFT JOIN AdSlots sl ON e.episode_id = sl.episode_id
        {where_sql}
        GROUP BY e.episode_id, e.channel_id, e.title, e.description, e.audio_url,
                 e.duration_seconds, e.published_at, e.status, e.created_at,
                 ch.title, ch.category, ch.creator_id, cr.display_name
        ORDER BY e.published_at DESC, e.episode_id DESC
        """,
        params,
    )
    return success(rows)


@content_bp.get("/episodes/<int:episode_id>")
def get_episode(episode_id: int):
    """Get full details for a single episode including attached ad slots."""
    ep = db.fetch_one(
        """
        SELECT e.*, ch.title AS channel_title, ch.category, ch.creator_id,
               cr.display_name AS creator_name,
               COUNT(DISTINCT lh.history_id) AS listen_count,
               COALESCE(ROUND(AVG(r.score), 2), 0) AS avg_rating
        FROM Episodes e
        INNER JOIN PodcastChannels ch ON e.channel_id = ch.channel_id
        INNER JOIN Creators cr ON ch.creator_id = cr.creator_id
        LEFT JOIN ListeningHistory lh ON e.episode_id = lh.episode_id
        LEFT JOIN Ratings r ON e.episode_id = r.episode_id
        WHERE e.episode_id = %s
        GROUP BY e.episode_id, ch.title, ch.category, ch.creator_id, cr.display_name
        """,
        (episode_id,),
    )
    if not ep:
        raise AppError("Không tìm thấy tập Podcast.", status_code=404)

    slots = db.fetch_all(
        """
        SELECT s.slot_id, s.slot_position, s.start_offset_seconds, s.status,
               ac.contract_id, ac.contract_code,
               a.ad_id, a.advertiser_name, a.title AS ad_title, a.duration_seconds AS ad_duration_seconds
        FROM AdSlots s
        INNER JOIN AdContracts ac ON s.contract_id = ac.contract_id
        INNER JOIN Advertisements a ON ac.ad_id = a.ad_id
        WHERE s.episode_id = %s
        ORDER BY s.start_offset_seconds ASC
        """,
        (episode_id,),
    )
    ep["ad_slots"] = slots
    return success(ep)


@content_bp.post("/episodes")
@roles_required("creator", "admin")
def create_episode():
    """Create a new episode under a channel owned by the authenticated creator."""
    user = get_current_user()
    data = _json_body()
    _require_fields(data, "channel_id", "title", "audio_url", "duration_seconds")

    channel_id = int(data["channel_id"])
    duration_seconds = int(data["duration_seconds"])
    status = str(data.get("status", "published")).strip().lower()
    if status not in ("draft", "published", "archived"):
        raise AppError("Trạng thái episode phải là draft, published hoặc archived.", status_code=400)
    if duration_seconds <= 0:
        raise AppError("Thời lượng tập (duration_seconds) phải lớn hơn 0.", status_code=400)

    channel = db.fetch_one("SELECT * FROM PodcastChannels WHERE channel_id = %s", (channel_id,))
    if not channel:
        raise AppError("Kênh Podcast không tồn tại.", status_code=404)
    if user["role"] != "admin" and channel["creator_id"] != user.get("creator_id"):
        raise AppError("Bạn không có quyền thêm tập vào kênh này.", status_code=403)

    _, episode_id = db.execute(
        """
        INSERT INTO Episodes (channel_id, title, description, audio_url, duration_seconds, status, published_at)
        VALUES (%s, %s, %s, %s, %s, %s, CASE WHEN %s = 'published' THEN NOW() ELSE NULL END)
        """,
        (
            channel_id,
            str(data["title"]).strip(),
            str(data.get("description") or "").strip() or None,
            str(data["audio_url"]).strip(),
            duration_seconds,
            status,
            status,
        ),
    )
    row = db.fetch_one("SELECT * FROM Episodes WHERE episode_id = %s", (episode_id,))
    return success(row, message="Tạo tập Podcast thành công.", status=201)


@content_bp.put("/episodes/<int:episode_id>")
@roles_required("creator", "admin")
def update_episode(episode_id: int):
    """Update an existing episode (respecting trigger constraints on duration_seconds)."""
    user = get_current_user()
    existing = db.fetch_one(
        """
        SELECT e.*, ch.creator_id
        FROM Episodes e
        INNER JOIN PodcastChannels ch ON e.channel_id = ch.channel_id
        WHERE e.episode_id = %s
        """,
        (episode_id,),
    )
    if not existing:
        raise AppError("Không tìm thấy tập Podcast.", status_code=404)
    if user["role"] != "admin" and existing["creator_id"] != user.get("creator_id"):
        raise AppError("Bạn không có quyền chỉnh sửa tập này.", status_code=403)

    data = _json_body()
    title = str(data.get("title") or existing["title"]).strip()
    description = data.get("description", existing["description"])
    audio_url = str(data.get("audio_url") or existing["audio_url"]).strip()
    duration_seconds = int(data.get("duration_seconds", existing["duration_seconds"]))
    if duration_seconds <= 0:
        raise AppError("Thời lượng tập phải lớn hơn 0.", status_code=400)

    # Rule 4: Không cho giảm thời lượng Episode xuống < 20 phút nếu đã gắn > 3 hợp đồng quảng cáo
    if duration_seconds < 1200 and existing["duration_seconds"] >= 1200:
        slot_stats = db.fetch_one(
            "SELECT COUNT(DISTINCT contract_id) AS distinct_contracts FROM AdSlots WHERE episode_id = %s",
            (episode_id,),
        )
        if slot_stats and slot_stats["distinct_contracts"] > 3:
            raise AppError(
                "Không thể giảm thời lượng Episode xuống dưới 20 phút vì đã có hơn 3 hợp đồng quảng cáo.",
                status_code=400,
            )

    status = str(data.get("status", existing["status"])).strip().lower()
    if status not in ("draft", "published", "archived"):
        raise AppError("Trạng thái episode không hợp lệ.", status_code=400)

    db.execute(
        """
        UPDATE Episodes
        SET title = %s,
            description = %s,
            audio_url = %s,
            duration_seconds = %s,
            status = %s,
            published_at = CASE
                WHEN %s = 'published' AND published_at IS NULL THEN NOW()
                ELSE published_at
            END
        WHERE episode_id = %s
        """,
        (title, description, audio_url, duration_seconds, status, status, episode_id),
    )
    updated = db.fetch_one("SELECT * FROM Episodes WHERE episode_id = %s", (episode_id,))
    return success(updated, message="Cập nhật tập Podcast thành công.")


@content_bp.delete("/episodes/<int:episode_id>")
@roles_required("creator", "admin")
def delete_episode(episode_id: int):
    """Delete an episode owned by the authenticated creator (or admin)."""
    user = get_current_user()
    existing = db.fetch_one(
        """
        SELECT e.episode_id, ch.creator_id
        FROM Episodes e
        INNER JOIN PodcastChannels ch ON e.channel_id = ch.channel_id
        WHERE e.episode_id = %s
        """,
        (episode_id,),
    )
    if not existing:
        raise AppError("Không tìm thấy tập Podcast.", status_code=404)
    if user["role"] != "admin" and existing["creator_id"] != user.get("creator_id"):
        raise AppError("Bạn không có quyền xóa tập này.", status_code=403)

    db.execute("DELETE FROM Episodes WHERE episode_id = %s", (episode_id,))
    return success({"deleted_episode_id": episode_id}, message="Đã xóa tập Podcast.")
