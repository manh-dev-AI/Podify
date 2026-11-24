"""Module 02: Listening & User Interaction RESTful API Blueprint (Vietnamese Schema)."""

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
    """Return home feed (channels, episodes, continue listening, user ratings)."""
    user = get_optional_user()
    user_id = user["user_id"] if user else ""

    channels = db.fetch_all(
        """
        SELECT ch.ma_kenh AS channel_id,
               ch.ma_creator AS creator_id,
               ch.tieu_de_kenh AS title,
               ch.mo_ta AS description,
               ch.the_loai AS category,
               cr.ten_hien_thi AS creator_name,
               COUNT(DISTINCT lh.ma_lich_su) AS total_listens,
               COUNT(DISTINCT s_all.ma_theo_doi) AS subscriber_count,
               COALESCE(ROUND(AVG(r.so_sao), 2), 0) AS avg_rating,
               MAX(CASE WHEN s_me.ma_nguoi_dung IS NOT NULL THEN 1 ELSE 0 END) AS subscribed
        FROM KenhPodcast ch
        JOIN NhaSangTao cr ON ch.ma_creator = cr.ma_creator
        LEFT JOIN TapPodcast e ON ch.ma_kenh = e.ma_kenh
        LEFT JOIN LichSuNghe lh ON e.ma_tap = lh.ma_tap
        LEFT JOIN DanhGia r ON e.ma_tap = r.ma_tap
        LEFT JOIN TheoDoi s_all ON ch.ma_kenh = s_all.ma_kenh
        LEFT JOIN TheoDoi s_me ON ch.ma_kenh = s_me.ma_kenh AND s_me.ma_nguoi_dung = %s
        GROUP BY ch.ma_kenh, ch.ma_creator, ch.tieu_de_kenh, ch.mo_ta, ch.the_loai, cr.ten_hien_thi
        ORDER BY total_listens DESC, ch.ma_kenh ASC
        """,
        (user_id,),
    )

    episodes = db.fetch_all(
        """
        SELECT e.ma_tap AS episode_id,
               e.ma_kenh AS channel_id,
               e.tieu_de_tap AS title,
               e.mo_ta AS description,
               e.duong_dan_audio AS audio_url,
               e.thoi_luong_giay AS duration_seconds,
               'published' AS status,
               e.ngay_phat_hanh AS published_at,
               ch.tieu_de_kenh AS channel_title,
               ch.the_loai AS category,
               ch.ma_creator AS creator_id,
               cr.ten_hien_thi AS creator_name,
               COUNT(DISTINCT lh_all.ma_lich_su) AS listen_count,
               COALESCE(ROUND(AVG(r_all.so_sao), 2), 0) AS avg_rating,
               MAX(r_me.so_sao) AS my_rating,
               MAX(r_me.binh_luan) AS my_comment
        FROM TapPodcast e
        JOIN KenhPodcast ch ON e.ma_kenh = ch.ma_kenh
        JOIN NhaSangTao cr ON ch.ma_creator = cr.ma_creator
        LEFT JOIN LichSuNghe lh_all ON e.ma_tap = lh_all.ma_tap
        LEFT JOIN DanhGia r_all ON e.ma_tap = r_all.ma_tap
        LEFT JOIN DanhGia r_me ON e.ma_tap = r_me.ma_tap AND r_me.ma_nguoi_dung = %s
        WHERE e.trang_thai = 'da_phat_hanh'
        GROUP BY e.ma_tap, e.ma_kenh, e.tieu_de_tap, e.mo_ta, e.duong_dan_audio,
                 e.thoi_luong_giay, e.ngay_phat_hanh,
                 ch.tieu_de_kenh, ch.the_loai, ch.ma_creator, cr.ten_hien_thi
        ORDER BY e.ngay_phat_hanh DESC, e.ma_tap ASC
        """,
        (user_id,),
    )

    history = []
    if user_id:
        history = db.fetch_all(
            """
            SELECT lh.ma_lich_su AS history_id,
                   lh.ma_tap AS episode_id,
                   lh.vi_tri_nghe_giay AS last_position_seconds,
                   lh.da_nghe_xong AS is_completed,
                   lh.thoi_diem_nghe AS listened_at,
                   lh.ngay_cap_nhat AS updated_at,
                   e.tieu_de_tap AS episode_title,
                   e.thoi_luong_giay AS duration_seconds,
                   e.duong_dan_audio AS audio_url,
                   ch.ma_kenh AS channel_id,
                   ch.tieu_de_kenh AS channel_title,
                   ch.ma_creator AS creator_id
            FROM LichSuNghe lh
            JOIN TapPodcast e ON lh.ma_tap = e.ma_tap
            JOIN KenhPodcast ch ON e.ma_kenh = ch.ma_kenh
            WHERE lh.ma_nguoi_dung = %s
            ORDER BY lh.ngay_cap_nhat DESC, lh.ma_lich_su DESC
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
        SELECT s.ma_theo_doi AS subscription_id,
               s.ma_kenh AS channel_id,
               s.ngay_theo_doi AS subscribed_at,
               s.bat_thong_bao AS notify_enabled,
               ch.tieu_de_kenh AS title,
               ch.mo_ta AS description,
               ch.the_loai AS category,
               ch.ma_creator AS creator_id,
               cr.ten_hien_thi AS creator_name,
               COUNT(DISTINCT e.ma_tap) AS episode_count
        FROM TheoDoi s
        JOIN KenhPodcast ch ON s.ma_kenh = ch.ma_kenh
        JOIN NhaSangTao cr ON ch.ma_creator = cr.ma_creator
        LEFT JOIN TapPodcast e ON ch.ma_kenh = e.ma_kenh
        WHERE s.ma_nguoi_dung = %s
        GROUP BY s.ma_theo_doi, s.ma_kenh, s.ngay_theo_doi, s.bat_thong_bao,
                 ch.tieu_de_kenh, ch.mo_ta, ch.the_loai, ch.ma_creator, cr.ten_hien_thi
        ORDER BY s.ngay_theo_doi DESC
        """,
        (user["user_id"],),
    )
    return success(rows)


@listening_bp.post("/subscriptions")
@login_required
def subscribe_channel():
    """Subscribe to a channel (enforces UNIQUE(ma_nguoi_dung, ma_kenh))."""
    user = get_current_user()
    data = _json_body()
    channel_id = str(data.get("channel_id") or "").strip()
    if not channel_id:
        raise AppError("Thiếu channel_id.", status_code=400)

    channel = db.fetch_one("SELECT ma_kenh AS channel_id, tieu_de_kenh AS title FROM KenhPodcast WHERE ma_kenh = %s", (channel_id,))
    if not channel:
        raise AppError("Kênh Podcast không tồn tại.", status_code=404)

    notify_enabled = bool(data.get("notify_enabled", True))
    sub_id = db.next_id("TD", "TheoDoi", "ma_theo_doi")
    db.execute(
        """
        INSERT INTO TheoDoi (ma_theo_doi, ma_nguoi_dung, ma_kenh, bat_thong_bao)
        VALUES (%s, %s, %s, %s)
        """,
        (sub_id, user["user_id"], channel_id, notify_enabled),
    )
    row = db.fetch_one(
        """
        SELECT ma_theo_doi AS subscription_id, ma_nguoi_dung AS user_id, ma_kenh AS channel_id,
               ngay_theo_doi AS subscribed_at, bat_thong_bao AS notify_enabled
        FROM TheoDoi WHERE ma_theo_doi = %s
        """,
        (sub_id,),
    )
    return success(row, message=f"Đã đăng ký kênh '{channel['title']}'.", status=201)


@listening_bp.delete("/subscriptions/<channel_id>")
@login_required
def unsubscribe_channel(channel_id: str):
    """Unsubscribe the authenticated user from a channel."""
    user = get_current_user()
    affected, _ = db.execute(
        "DELETE FROM TheoDoi WHERE ma_nguoi_dung = %s AND ma_kenh = %s",
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
        SELECT lh.ma_lich_su AS history_id,
               lh.ma_tap AS episode_id,
               lh.vi_tri_nghe_giay AS last_position_seconds,
               lh.da_nghe_xong AS is_completed,
               lh.thoi_diem_nghe AS listened_at,
               lh.ngay_cap_nhat AS updated_at,
               e.tieu_de_tap AS episode_title,
               e.thoi_luong_giay AS duration_seconds,
               e.duong_dan_audio AS audio_url,
               ch.ma_kenh AS channel_id,
               ch.tieu_de_kenh AS channel_title,
               r.so_sao AS my_rating
        FROM LichSuNghe lh
        JOIN TapPodcast e ON lh.ma_tap = e.ma_tap
        JOIN KenhPodcast ch ON e.ma_kenh = ch.ma_kenh
        LEFT JOIN DanhGia r ON r.ma_tap = e.ma_tap AND r.ma_nguoi_dung = lh.ma_nguoi_dung
        WHERE lh.ma_nguoi_dung = %s
        ORDER BY lh.ngay_cap_nhat DESC, lh.ma_lich_su DESC
        """,
        (user["user_id"],),
    )
    return success(rows)


@listening_bp.delete("/history/<history_id>")
@login_required
def delete_history_item(history_id: str):
    """Delete a specific listening history record owned by the current user."""
    user = get_current_user()
    affected, _ = db.execute(
        "DELETE FROM LichSuNghe WHERE ma_lich_su = %s AND ma_nguoi_dung = %s",
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
    episode_id = str(data.get("episode_id") or "").strip()
    if not episode_id:
        raise AppError("Thiếu episode_id.", status_code=400)

    ep = db.fetch_one("SELECT ma_tap AS episode_id, thoi_luong_giay AS duration_seconds FROM TapPodcast WHERE ma_tap = %s", (episode_id,))
    if not ep:
        raise AppError("Không tìm thấy tập Podcast.", status_code=404)

    position = max(0, int(data.get("position_seconds", 0)))
    position = min(position, int(ep["duration_seconds"]))
    is_completed = bool(data.get("is_completed", False)) or position >= int(ep["duration_seconds"])
    history_id = str(data.get("history_id") or "").strip() or None
    new_session = bool(data.get("new_session", False))

    if history_id and not new_session:
        affected, _ = db.execute(
            """
            UPDATE LichSuNghe
            SET vi_tri_nghe_giay = %s, da_nghe_xong = %s
            WHERE ma_lich_su = %s AND ma_nguoi_dung = %s AND ma_tap = %s
            """,
            (position, is_completed, history_id, user["user_id"], episode_id),
        )
        if affected > 0:
            row = db.fetch_one(
                """
                SELECT ma_lich_su AS history_id, ma_nguoi_dung AS user_id, ma_tap AS episode_id,
                       vi_tri_nghe_giay AS last_position_seconds, da_nghe_xong AS is_completed,
                       thoi_diem_nghe AS listened_at, ngay_cap_nhat AS updated_at
                FROM LichSuNghe WHERE ma_lich_su = %s
                """,
                (history_id,),
            )
            return success(row, message="Đã cập nhật tiến trình nghe.")

    if not new_session:
        latest = db.fetch_one(
            """
            SELECT ma_lich_su AS history_id FROM LichSuNghe
            WHERE ma_nguoi_dung = %s AND ma_tap = %s AND da_nghe_xong = FALSE
            ORDER BY ngay_cap_nhat DESC, ma_lich_su DESC
            LIMIT 1
            """,
            (user["user_id"], episode_id),
        )
        if latest:
            db.execute(
                """
                UPDATE LichSuNghe
                SET vi_tri_nghe_giay = %s, da_nghe_xong = %s
                WHERE ma_lich_su = %s
                """,
                (position, is_completed, latest["history_id"]),
            )
            row = db.fetch_one(
                """
                SELECT ma_lich_su AS history_id, ma_nguoi_dung AS user_id, ma_tap AS episode_id,
                       vi_tri_nghe_giay AS last_position_seconds, da_nghe_xong AS is_completed,
                       thoi_diem_nghe AS listened_at, ngay_cap_nhat AS updated_at
                FROM LichSuNghe WHERE ma_lich_su = %s
                """,
                (latest["history_id"],),
            )
            return success(row, message="Đã lưu tiến trình nghe.")

    new_id = db.next_id("LS", "LichSuNghe", "ma_lich_su")
    db.execute(
        """
        INSERT INTO LichSuNghe (ma_lich_su, ma_nguoi_dung, ma_tap, vi_tri_nghe_giay, da_nghe_xong)
        VALUES (%s, %s, %s, %s, %s)
        """,
        (new_id, user["user_id"], episode_id, position, is_completed),
    )
    row = db.fetch_one(
        """
        SELECT ma_lich_su AS history_id, ma_nguoi_dung AS user_id, ma_tap AS episode_id,
               vi_tri_nghe_giay AS last_position_seconds, da_nghe_xong AS is_completed,
               thoi_diem_nghe AS listened_at, ngay_cap_nhat AS updated_at
        FROM LichSuNghe WHERE ma_lich_su = %s
        """,
        (new_id,),
    )
    return success(row, message="Đã ghi nhận lượt nghe mới.", status=201)


@listening_bp.get("/ratings")
def list_ratings():
    """List ratings (by current user if logged in, plus episode averages)."""
    user = get_optional_user()
    user_id = user["user_id"] if user else ""
    rows = db.fetch_all(
        """
        SELECT e.ma_tap AS episode_id,
               e.tieu_de_tap AS episode_title,
               e.thoi_luong_giay AS duration_seconds,
               ch.ma_kenh AS channel_id,
               ch.tieu_de_kenh AS channel_title,
               COALESCE(ROUND(AVG(r_all.so_sao), 2), 0) AS avg_rating,
               COUNT(r_all.ma_danh_gia) AS rating_count,
               MAX(r_me.so_sao) AS my_score,
               MAX(r_me.binh_luan) AS my_comment,
               MAX(r_me.ngay_cap_nhat) AS my_rated_at
        FROM TapPodcast e
        JOIN KenhPodcast ch ON e.ma_kenh = ch.ma_kenh
        LEFT JOIN DanhGia r_all ON e.ma_tap = r_all.ma_tap
        LEFT JOIN DanhGia r_me ON e.ma_tap = r_me.ma_tap AND r_me.ma_nguoi_dung = %s
        GROUP BY e.ma_tap, e.tieu_de_tap, e.thoi_luong_giay, ch.ma_kenh, ch.tieu_de_kenh
        ORDER BY e.ma_tap ASC
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
    episode_id = str(data.get("episode_id") or "").strip()
    score = data.get("score")
    if not episode_id or score is None:
        raise AppError("Thiếu episode_id hoặc score.", status_code=400)

    try:
        score_int = int(score)
    except (TypeError, ValueError) as exc:
        raise AppError("Điểm đánh giá (score) phải là số nguyên từ 1 đến 5.", status_code=400) from exc

    if not (1 <= score_int <= 5):
        raise AppError("Điểm đánh giá (score) phải nằm trong khoảng 1 đến 5.", status_code=400)

    ep = db.fetch_one("SELECT ma_tap AS episode_id, tieu_de_tap AS title FROM TapPodcast WHERE ma_tap = %s", (episode_id,))
    if not ep:
        raise AppError("Tập Podcast không tồn tại.", status_code=404)

    comment = str(data.get("comment") or "").strip() or None
    existing_rating = db.fetch_one(
        "SELECT ma_danh_gia AS rating_id FROM DanhGia WHERE ma_nguoi_dung = %s AND ma_tap = %s",
        (user["user_id"], episode_id),
    )
    if existing_rating:
        db.execute(
            "UPDATE DanhGia SET so_sao = %s, binh_luan = %s WHERE ma_danh_gia = %s",
            (score_int, comment, existing_rating["rating_id"]),
        )
    else:
        new_rid = db.next_id("DG", "DanhGia", "ma_danh_gia")
        db.execute(
            "INSERT INTO DanhGia (ma_danh_gia, ma_nguoi_dung, ma_tap, so_sao, binh_luan) VALUES (%s, %s, %s, %s, %s)",
            (new_rid, user["user_id"], episode_id, score_int, comment),
        )

    row = db.fetch_one(
        """
        SELECT ma_danh_gia AS rating_id, ma_nguoi_dung AS user_id, ma_tap AS episode_id,
               so_sao AS score, binh_luan AS comment,
               ngay_danh_gia AS created_at, ngay_cap_nhat AS updated_at
        FROM DanhGia WHERE ma_nguoi_dung = %s AND ma_tap = %s
        """,
        (user["user_id"], episode_id),
    )
    return success(row, message=f"Đã lưu đánh giá {score_int}★ cho '{ep['title']}'.")


@listening_bp.delete("/ratings/<episode_id>")
@login_required
def delete_rating(episode_id: str):
    """Delete the current user's rating for an episode."""
    user = get_current_user()
    affected, _ = db.execute(
        "DELETE FROM DanhGia WHERE ma_nguoi_dung = %s AND ma_tap = %s",
        (user["user_id"], episode_id),
    )
    if affected == 0:
        raise AppError("Không tìm thấy đánh giá của bạn cho tập này.", status_code=404)
    return success({"deleted_episode_id": episode_id}, message="Đã xóa đánh giá.")
