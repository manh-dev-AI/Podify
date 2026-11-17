"""Module 02: Listening & User Interaction RESTful API Blueprint."""

from flask import Blueprint, request

from common.auth import get_current_user, get_optional_user, login_required
from common.errors import AppError
from common.response import success
from config import db

listening_bp = Blueprint("listening", __name__, url_prefix="/api/listening")


def _json_body() -> dict:
    data = request.get_json(silent=True)
    if not isinstance(data, dict):
        raise AppError("Request body phải là JSON hợp lệ.", status_code=400, code="INVALID_JSON")
    return data


@listening_bp.get("/home")
def get_home_feed():
    """Return home feed (channels, episodes, continue listening, user ratings, activities)."""
    user = get_optional_user()
    user_id = user["user_id"] if user else 0

    channels = db.fetch_all(
        """
        SELECT ch.channel_id, ch.creator_id, ch.title, ch.description, ch.category,
               cr.display_name AS creator_name,
               COUNT(DISTINCT lh.history_id) AS total_listens,
               COUNT(DISTINCT s_all.subscription_id) AS subscriber_count,
               COALESCE(ROUND(AVG(r.score), 2), 0) AS avg_rating,
               MAX(CASE WHEN s_me.user_id IS NOT NULL THEN 1 ELSE 0 END) AS subscribed
        FROM PodcastChannels ch
        INNER JOIN Creators cr ON ch.creator_id = cr.creator_id
        LEFT JOIN Episodes e ON ch.channel_id = e.channel_id
        LEFT JOIN ListeningHistory lh ON e.episode_id = lh.episode_id
        LEFT JOIN Ratings r ON e.episode_id = r.episode_id
        LEFT JOIN Subscriptions s_all ON ch.channel_id = s_all.channel_id
        LEFT JOIN Subscriptions s_me ON ch.channel_id = s_me.channel_id AND s_me.user_id = %s
        GROUP BY ch.channel_id, ch.creator_id, ch.title, ch.description, ch.category, cr.display_name
        ORDER BY total_listens DESC, ch.channel_id ASC
        """,
        (user_id,),
    )

    episodes = db.fetch_all(
        """
        SELECT e.episode_id, e.channel_id, e.title, e.description, e.audio_url,
               e.duration_seconds, e.status, e.published_at,
               ch.title AS channel_title, ch.category, ch.creator_id,
               cr.display_name AS creator_name,
               COUNT(DISTINCT lh_all.history_id) AS listen_count,
               COALESCE(ROUND(AVG(r_all.score), 2), 0) AS avg_rating,
               MAX(r_me.score) AS my_rating,
               MAX(r_me.comment) AS my_comment
        FROM Episodes e
        INNER JOIN PodcastChannels ch ON e.channel_id = ch.channel_id
        INNER JOIN Creators cr ON ch.creator_id = cr.creator_id
        LEFT JOIN ListeningHistory lh_all ON e.episode_id = lh_all.episode_id
        LEFT JOIN Ratings r_all ON e.episode_id = r_all.episode_id
        LEFT JOIN Ratings r_me ON e.episode_id = r_me.episode_id AND r_me.user_id = %s
        WHERE e.status = 'published'
        GROUP BY e.episode_id, e.channel_id, e.title, e.description, e.audio_url,
                 e.duration_seconds, e.status, e.published_at,
                 ch.title, ch.category, ch.creator_id, cr.display_name
        ORDER BY e.published_at DESC, e.episode_id ASC
        """,
        (user_id,),
    )

    history = []
    if user_id:
        history = db.fetch_all(
            """
            SELECT lh.history_id, lh.episode_id, lh.last_position_seconds,
                   lh.is_completed, lh.listened_at, lh.updated_at,
                   e.title AS episode_title, e.duration_seconds, e.audio_url,
                   ch.channel_id, ch.title AS channel_title, ch.creator_id
            FROM ListeningHistory lh
            INNER JOIN Episodes e ON lh.episode_id = e.episode_id
            INNER JOIN PodcastChannels ch ON e.channel_id = ch.channel_id
            WHERE lh.user_id = %s
            ORDER BY lh.updated_at DESC, lh.history_id DESC
            LIMIT 20
            """,
            (user_id,),
        )

    return success(
        {
            "channels": channels,
            "episodes": episodes,
            "history": history,
            "continue_episode": history[0] if history else (episodes[0] if episodes else None),
        }
    )


@listening_bp.get("/subscriptions")
@login_required
def list_subscriptions():
    """List channels subscribed by the authenticated user."""
    user = get_current_user()
    rows = db.fetch_all(
        """
        SELECT s.subscription_id, s.channel_id, s.subscribed_at, s.notify_enabled,
               ch.title, ch.description, ch.category, ch.creator_id,
               cr.display_name AS creator_name,
               COUNT(DISTINCT e.episode_id) AS episode_count
        FROM Subscriptions s
        INNER JOIN PodcastChannels ch ON s.channel_id = ch.channel_id
        INNER JOIN Creators cr ON ch.creator_id = cr.creator_id
        LEFT JOIN Episodes e ON ch.channel_id = e.channel_id
        WHERE s.user_id = %s
        GROUP BY s.subscription_id, s.channel_id, s.subscribed_at, s.notify_enabled,
                 ch.title, ch.description, ch.category, ch.creator_id, cr.display_name
        ORDER BY s.subscribed_at DESC
        """,
        (user["user_id"],),
    )
    return success(rows)


@listening_bp.post("/subscriptions")
@login_required
def subscribe_channel():
    """Subscribe to a channel (enforces UQ_Subscriptions_User_Channel)."""
    user = get_current_user()
    data = _json_body()
    channel_id = data.get("channel_id")
    if not channel_id:
        raise AppError("Thiếu channel_id.", status_code=400)

    channel = db.fetch_one("SELECT channel_id, title FROM PodcastChannels WHERE channel_id = %s", (int(channel_id),))
    if not channel:
        raise AppError("Kênh Podcast không tồn tại.", status_code=404)

    notify_enabled = bool(data.get("notify_enabled", True))
    _, sub_id = db.execute(
        """
        INSERT INTO Subscriptions (user_id, channel_id, notify_enabled)
        VALUES (%s, %s, %s)
        """,
        (user["user_id"], int(channel_id), notify_enabled),
    )
    row = db.fetch_one("SELECT * FROM Subscriptions WHERE subscription_id = %s", (sub_id,))
    return success(row, message=f"Đã đăng ký kênh '{channel['title']}'.", status=201)


@listening_bp.delete("/subscriptions/<int:channel_id>")
@login_required
def unsubscribe_channel(channel_id: int):
    """Unsubscribe the authenticated user from a channel."""
    user = get_current_user()
    affected, _ = db.execute(
        "DELETE FROM Subscriptions WHERE user_id = %s AND channel_id = %s",
        (user["user_id"], channel_id),
    )
    if affected == 0:
        raise AppError("Bạn chưa đăng ký kênh này.", status_code=404)
    return success({"unsubscribed_channel_id": channel_id}, message="Đã hủy theo dõi kênh.")


@listening_bp.get("/history")
@login_required
def get_history():
    """Return listening history for the authenticated user."""
    user = get_current_user()
    rows = db.fetch_all(
        """
        SELECT lh.history_id, lh.episode_id, lh.last_position_seconds,
               lh.is_completed, lh.listened_at, lh.updated_at,
               e.title AS episode_title, e.duration_seconds, e.audio_url,
               ch.channel_id, ch.title AS channel_title,
               r.score AS my_rating
        FROM ListeningHistory lh
        INNER JOIN Episodes e ON lh.episode_id = e.episode_id
        INNER JOIN PodcastChannels ch ON e.channel_id = ch.channel_id
        LEFT JOIN Ratings r ON r.episode_id = e.episode_id AND r.user_id = lh.user_id
        WHERE lh.user_id = %s
        ORDER BY lh.updated_at DESC, lh.history_id DESC
        """,
        (user["user_id"],),
    )
    return success(rows)


@listening_bp.delete("/history/<int:history_id>")
@login_required
def delete_history_item(history_id: int):
    """Delete a specific listening history record owned by the current user."""
    user = get_current_user()
    affected, _ = db.execute(
        "DELETE FROM ListeningHistory WHERE history_id = %s AND user_id = %s",
        (history_id, user["user_id"]),
    )
    if affected == 0:
        raise AppError("Không tìm thấy mục lịch sử nghe.", status_code=404)
    return success({"deleted_history_id": history_id}, message="Đã xóa mục khỏi lịch sử nghe.")


@listening_bp.post("/progress")
@login_required
def save_progress():
    """Create a new listening session or update an existing session's playback progress."""
    user = get_current_user()
    data = _json_body()
    episode_id = data.get("episode_id")
    if not episode_id:
        raise AppError("Thiếu episode_id.", status_code=400)

    ep = db.fetch_one("SELECT episode_id, duration_seconds FROM Episodes WHERE episode_id = %s", (int(episode_id),))
    if not ep:
        raise AppError("Không tìm thấy tập Podcast.", status_code=404)

    position = max(0, int(data.get("position_seconds", 0)))
    position = min(position, int(ep["duration_seconds"]))
    is_completed = bool(data.get("is_completed", False)) or position >= int(ep["duration_seconds"])
    history_id = data.get("history_id")
    new_session = bool(data.get("new_session", False))

    if history_id and not new_session:
        affected, _ = db.execute(
            """
            UPDATE ListeningHistory
            SET last_position_seconds = %s, is_completed = %s
            WHERE history_id = %s AND user_id = %s AND episode_id = %s
            """,
            (position, is_completed, int(history_id), user["user_id"], int(episode_id)),
        )
        if affected > 0:
            row = db.fetch_one("SELECT * FROM ListeningHistory WHERE history_id = %s", (int(history_id),))
            return success(row, message="Đã cập nhật tiến trình nghe.")

    if not new_session:
        latest = db.fetch_one(
            """
            SELECT history_id FROM ListeningHistory
            WHERE user_id = %s AND episode_id = %s AND is_completed = FALSE
            ORDER BY updated_at DESC, history_id DESC
            LIMIT 1
            """,
            (user["user_id"], int(episode_id)),
        )
        if latest:
            db.execute(
                """
                UPDATE ListeningHistory
                SET last_position_seconds = %s, is_completed = %s
                WHERE history_id = %s
                """,
                (position, is_completed, latest["history_id"]),
            )
            row = db.fetch_one("SELECT * FROM ListeningHistory WHERE history_id = %s", (latest["history_id"],))
            return success(row, message="Đã lưu tiến trình nghe.")

    _, new_id = db.execute(
        """
        INSERT INTO ListeningHistory (user_id, episode_id, last_position_seconds, is_completed)
        VALUES (%s, %s, %s, %s)
        """,
        (user["user_id"], int(episode_id), position, is_completed),
    )
    row = db.fetch_one("SELECT * FROM ListeningHistory WHERE history_id = %s", (new_id,))
    return success(row, message="Đã ghi nhận lượt nghe mới.", status=201)


@listening_bp.get("/ratings")
def list_ratings():
    """List ratings (by current user if logged in, plus episode averages)."""
    user = get_optional_user()
    user_id = user["user_id"] if user else 0
    rows = db.fetch_all(
        """
        SELECT e.episode_id, e.title AS episode_title, e.duration_seconds,
               ch.channel_id, ch.title AS channel_title,
               COALESCE(ROUND(AVG(r_all.score), 2), 0) AS avg_rating,
               COUNT(r_all.rating_id) AS rating_count,
               MAX(r_me.score) AS my_score,
               MAX(r_me.comment) AS my_comment,
               MAX(r_me.updated_at) AS my_rated_at
        FROM Episodes e
        INNER JOIN PodcastChannels ch ON e.channel_id = ch.channel_id
        LEFT JOIN Ratings r_all ON e.episode_id = r_all.episode_id
        LEFT JOIN Ratings r_me ON e.episode_id = r_me.episode_id AND r_me.user_id = %s
        GROUP BY e.episode_id, e.title, e.duration_seconds, ch.channel_id, ch.title
        ORDER BY e.episode_id ASC
        """,
        (user_id,),
    )
    return success(rows)


@listening_bp.post("/ratings")
@login_required
def upsert_rating():
    """Submit or update a 1-5 star rating for an episode."""
    user = get_current_user()
    data = _json_body()
    episode_id = data.get("episode_id")
    score = data.get("score")
    if episode_id is None or score is None:
        raise AppError("Thiếu episode_id hoặc score.", status_code=400)

    try:
        score_int = int(score)
    except (TypeError, ValueError) as exc:
        raise AppError("Điểm đánh giá (score) phải là số nguyên từ 1 đến 5.", status_code=400) from exc

    if not (1 <= score_int <= 5):
        raise AppError("Điểm đánh giá (score) phải nằm trong khoảng 1 đến 5.", status_code=400)

    ep = db.fetch_one("SELECT episode_id, title FROM Episodes WHERE episode_id = %s", (int(episode_id),))
    if not ep:
        raise AppError("Tập Podcast không tồn tại.", status_code=404)

    comment = str(data.get("comment") or "").strip() or None
    db.execute(
        """
        INSERT INTO Ratings (user_id, episode_id, score, comment)
        VALUES (%s, %s, %s, %s)
        ON DUPLICATE KEY UPDATE score = VALUES(score), comment = VALUES(comment)
        """,
        (user["user_id"], int(episode_id), score_int, comment),
    )
    row = db.fetch_one(
        "SELECT * FROM Ratings WHERE user_id = %s AND episode_id = %s",
        (user["user_id"], int(episode_id)),
    )
    return success(row, message=f"Đã lưu đánh giá {score_int}★ cho '{ep['title']}'.")


@listening_bp.delete("/ratings/<int:episode_id>")
@login_required
def delete_rating(episode_id: int):
    """Delete the current user's rating for an episode."""
    user = get_current_user()
    affected, _ = db.execute(
        "DELETE FROM Ratings WHERE user_id = %s AND episode_id = %s",
        (user["user_id"], episode_id),
    )
    if affected == 0:
        raise AppError("Không tìm thấy đánh giá của bạn cho tập này.", status_code=404)
    return success({"deleted_episode_id": episode_id}, message="Đã xóa đánh giá.")
