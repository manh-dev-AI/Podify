"""Module 01: Content Management RESTful API Blueprint (Vietnamese Schema)."""

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

_ROLE_TO_VI = {"user": "nguoi_nghe", "creator": "nha_sang_tao", "admin": "quan_tri"}
_EP_STATUS_TO_VI = {"draft": "nhap", "published": "da_phat_hanh", "archived": "luu_tru"}
_EP_STATUS_TO_EN = {"nhap": "draft", "da_phat_hanh": "published", "luu_tru": "archived"}

_EP_STATUS_SQL = """
    CASE e.trang_thai
        WHEN 'da_phat_hanh' THEN 'published'
        WHEN 'luu_tru' THEN 'archived'
        ELSE 'draft'
    END
"""


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


def _verify_password(stored_hash: str, raw_password: str) -> bool:
    if stored_hash.startswith(("pbkdf2:", "scrypt:")):
        return check_password_hash(stored_hash, raw_password)
    return stored_hash in (raw_password, f"hash_{raw_password}")


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
        "SELECT ten_dang_nhap AS username, email FROM NguoiDung WHERE ten_dang_nhap = %s OR email = %s",
        (username, email),
    )
    if existing_user:
        if existing_user["username"].lower() == username.lower():
            raise AppError("Tên đăng nhập này đã được sử dụng.", status_code=409, code="USERNAME_EXISTS")
        raise AppError("Email này đã được đăng ký tài khoản khác.", status_code=409, code="EMAIL_EXISTS")

    password_hash = generate_password_hash(password, method="pbkdf2:sha256")
    display_name = str(data.get("display_name") or full_name).strip()
    bio = str(data.get("bio") or "").strip() or None
    vai_tro_vi = _ROLE_TO_VI[role]

    user_id = db.next_id("ND", "NguoiDung", "ma_nguoi_dung")
    creator_id = db.next_id("NST", "NhaSangTao", "ma_creator") if role == "creator" else None

    with db.get_cursor(dictionary=True, commit=True) as cur:
        cur.execute(
            """
            INSERT INTO NguoiDung (ma_nguoi_dung, ten_dang_nhap, email, mat_khau, ho_ten, vai_tro, anh_dai_dien)
            VALUES (%s, %s, %s, %s, %s, %s, %s)
            """,
            (user_id, username, email, password_hash, full_name, vai_tro_vi, data.get("avatar_url")),
        )
        if creator_id:
            cur.execute(
                """
                INSERT INTO NhaSangTao (ma_creator, ma_nguoi_dung, ten_hien_thi, tieu_su, da_xac_minh)
                VALUES (%s, %s, %s, %s, FALSE)
                """,
                (creator_id, user_id, display_name, bio),
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
        SELECT ma_nguoi_dung AS user_id, mat_khau AS password_hash,
               CASE vai_tro
                   WHEN 'nha_sang_tao' THEN 'creator'
                   WHEN 'quan_tri' THEN 'admin'
                   ELSE 'user'
               END AS role
        FROM NguoiDung
        WHERE ten_dang_nhap = %s OR email = %s
        """,
        (identifier, identifier.lower()),
    )
    if not row or not _verify_password(row["password_hash"], password):
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
        SELECT u.ma_nguoi_dung AS user_id,
               u.ten_dang_nhap AS username,
               u.ho_ten AS full_name,
               CASE u.vai_tro
                   WHEN 'nha_sang_tao' THEN 'creator'
                   WHEN 'quan_tri' THEN 'admin'
                   ELSE 'user'
               END AS role,
               c.ma_creator AS creator_id,
               c.ten_hien_thi AS creator_display_name
        FROM NguoiDung u
        LEFT JOIN NhaSangTao c ON u.ma_nguoi_dung = c.ma_nguoi_dung
        ORDER BY u.ma_nguoi_dung ASC
        """
    )
    return success(rows)


@content_bp.get("/creators")
def list_creators():
    """List creators along with channel, episode, and subscriber counts."""
    rows = db.fetch_all(
        """
        SELECT cr.ma_creator AS creator_id,
               cr.ma_nguoi_dung AS user_id,
               cr.ten_hien_thi AS display_name,
               cr.tieu_su AS bio,
               cr.da_xac_minh AS verified,
               cr.ngay_tao AS created_at,
               u.ten_dang_nhap AS username,
               u.ho_ten AS full_name,
               COUNT(DISTINCT ch.ma_kenh) AS channel_count,
               COUNT(DISTINCT e.ma_tap) AS episode_count,
               COUNT(DISTINCT s.ma_theo_doi) AS subscriber_count
        FROM NhaSangTao cr
        JOIN NguoiDung u ON cr.ma_nguoi_dung = u.ma_nguoi_dung
        LEFT JOIN KenhPodcast ch ON cr.ma_creator = ch.ma_creator
        LEFT JOIN TapPodcast e ON ch.ma_kenh = e.ma_kenh
        LEFT JOIN TheoDoi s ON ch.ma_kenh = s.ma_kenh
        GROUP BY cr.ma_creator, cr.ma_nguoi_dung, cr.ten_hien_thi, cr.tieu_su, cr.da_xac_minh,
                 cr.ngay_tao, u.ten_dang_nhap, u.ho_ten
        ORDER BY cr.ma_creator ASC
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
            "UPDATE NhaSangTao SET ten_hien_thi = %s, tieu_su = %s WHERE ma_creator = %s",
            (display_name, bio, user["creator_id"]),
        )
    else:
        new_cid = db.next_id("NST", "NhaSangTao", "ma_creator")
        db.execute(
            "INSERT INTO NhaSangTao (ma_creator, ma_nguoi_dung, ten_hien_thi, tieu_su, da_xac_minh) VALUES (%s, %s, %s, %s, FALSE)",
            (new_cid, user["user_id"], display_name, bio),
        )
    return success(load_user_with_creator(user["user_id"]), message="Cập nhật hồ sơ Creator thành công.")


@content_bp.get("/channels")
def list_channels():
    """List or search podcast channels with aggregated stats."""
    q = request.args.get("q", "").strip()
    category = request.args.get("category", "").strip()
    creator_id = request.args.get("creator_id", "").strip()
    current = get_optional_user()
    current_uid = current["user_id"] if current else ""

    where_clauses = []
    params: list = [current_uid]

    if q:
        like = f"%{q}%"
        where_clauses.append("(ch.tieu_de_kenh LIKE %s OR ch.mo_ta LIKE %s OR cr.ten_hien_thi LIKE %s)")
        params.extend([like, like, like])
    if category:
        where_clauses.append("ch.the_loai = %s")
        params.append(category)
    if creator_id:
        where_clauses.append("ch.ma_creator = %s")
        params.append(creator_id)

    where_sql = f"WHERE {' AND '.join(where_clauses)}" if where_clauses else ""

    rows = db.fetch_all(
        f"""
        SELECT ch.ma_kenh AS channel_id,
               ch.ma_creator AS creator_id,
               ch.tieu_de_kenh AS title,
               ch.mo_ta AS description,
               ch.the_loai AS category,
               ch.anh_bia AS cover_image_url,
               ch.ngay_tao AS created_at,
               ch.ngay_cap_nhat AS updated_at,
               cr.ten_hien_thi AS creator_name,
               cr.da_xac_minh AS creator_verified,
               COUNT(DISTINCT e.ma_tap) AS episode_count,
               COUNT(DISTINCT s.ma_theo_doi) AS subscriber_count,
               COALESCE(ROUND(AVG(r.so_sao), 2), 0) AS avg_rating,
               COUNT(DISTINCT lh.ma_lich_su) AS total_listens,
               MAX(CASE WHEN s.ma_nguoi_dung = %s THEN 1 ELSE 0 END) AS is_subscribed
        FROM KenhPodcast ch
        JOIN NhaSangTao cr ON ch.ma_creator = cr.ma_creator
        LEFT JOIN TapPodcast e ON ch.ma_kenh = e.ma_kenh
        LEFT JOIN TheoDoi s ON ch.ma_kenh = s.ma_kenh
        LEFT JOIN DanhGia r ON e.ma_tap = r.ma_tap
        LEFT JOIN LichSuNghe lh ON e.ma_tap = lh.ma_tap
        {where_sql}
        GROUP BY ch.ma_kenh, ch.ma_creator, ch.tieu_de_kenh, ch.mo_ta, ch.the_loai,
                 ch.anh_bia, ch.ngay_tao, ch.ngay_cap_nhat,
                 cr.ten_hien_thi, cr.da_xac_minh
        ORDER BY total_listens DESC, ch.ma_kenh ASC
        """,
        params,
    )
    return success(rows)


@content_bp.get("/channels/<channel_id>")
def get_channel(channel_id: str):
    """Get a single channel's details and its episodes."""
    current = get_optional_user()
    current_uid = current["user_id"] if current else ""

    channel = db.fetch_one(
        """
        SELECT ch.ma_kenh AS channel_id,
               ch.ma_creator AS creator_id,
               ch.tieu_de_kenh AS title,
               ch.mo_ta AS description,
               ch.the_loai AS category,
               ch.anh_bia AS cover_image_url,
               ch.ngay_tao AS created_at,
               ch.ngay_cap_nhat AS updated_at,
               cr.ten_hien_thi AS creator_name,
               cr.tieu_su AS creator_bio,
               cr.da_xac_minh AS creator_verified,
               COUNT(DISTINCT s.ma_theo_doi) AS subscriber_count,
               COALESCE(ROUND(AVG(r.so_sao), 2), 0) AS avg_rating,
               MAX(CASE WHEN s.ma_nguoi_dung = %s THEN 1 ELSE 0 END) AS is_subscribed
        FROM KenhPodcast ch
        JOIN NhaSangTao cr ON ch.ma_creator = cr.ma_creator
        LEFT JOIN TheoDoi s ON ch.ma_kenh = s.ma_kenh
        LEFT JOIN TapPodcast e ON ch.ma_kenh = e.ma_kenh
        LEFT JOIN DanhGia r ON e.ma_tap = r.ma_tap
        WHERE ch.ma_kenh = %s
        GROUP BY ch.ma_kenh, ch.ma_creator, ch.tieu_de_kenh, ch.mo_ta, ch.the_loai,
                 ch.anh_bia, ch.ngay_tao, ch.ngay_cap_nhat,
                 cr.ten_hien_thi, cr.tieu_su, cr.da_xac_minh
        """,
        (current_uid, channel_id),
    )
    if not channel:
        raise AppError("Không tìm thấy kênh Podcast.", status_code=404)

    episodes = db.fetch_all(
        f"""
        SELECT e.ma_tap AS episode_id,
               e.ma_kenh AS channel_id,
               e.tieu_de_tap AS title,
               e.mo_ta AS description,
               e.duong_dan_audio AS audio_url,
               e.thoi_luong_giay AS duration_seconds,
               e.ngay_phat_hanh AS published_at,
               {_EP_STATUS_SQL} AS status,
               e.ngay_tao AS created_at,
               COUNT(DISTINCT lh.ma_lich_su) AS listen_count,
               COALESCE(ROUND(AVG(r.so_sao), 2), 0) AS avg_rating,
               COUNT(DISTINCT sl.ma_vi_tri) AS ad_slot_count
        FROM TapPodcast e
        LEFT JOIN LichSuNghe lh ON e.ma_tap = lh.ma_tap
        LEFT JOIN DanhGia r ON e.ma_tap = r.ma_tap
        LEFT JOIN ViTriQC sl ON e.ma_tap = sl.ma_tap
        WHERE e.ma_kenh = %s
        GROUP BY e.ma_tap, e.ma_kenh, e.tieu_de_tap, e.mo_ta, e.duong_dan_audio,
                 e.thoi_luong_giay, e.ngay_phat_hanh, e.trang_thai, e.ngay_tao
        ORDER BY e.ngay_phat_hanh DESC, e.ma_tap DESC
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
    channel_id = db.next_id("KP", "KenhPodcast", "ma_kenh")
    db.execute(
        """
        INSERT INTO KenhPodcast (ma_kenh, ma_creator, tieu_de_kenh, mo_ta, the_loai, anh_bia)
        VALUES (%s, %s, %s, %s, %s, %s)
        """,
        (
            channel_id,
            user["creator_id"],
            str(data["title"]).strip(),
            str(data.get("description") or "").strip() or None,
            str(data["category"]).strip(),
            data.get("cover_image_url"),
        ),
    )
    row = db.fetch_one(
        """
        SELECT ma_kenh AS channel_id, ma_creator AS creator_id, tieu_de_kenh AS title,
               mo_ta AS description, the_loai AS category, anh_bia AS cover_image_url,
               ngay_tao AS created_at, ngay_cap_nhat AS updated_at
        FROM KenhPodcast WHERE ma_kenh = %s
        """,
        (channel_id,),
    )
    return success(row, message="Tạo kênh Podcast thành công.", status=201)


@content_bp.put("/channels/<channel_id>")
@roles_required("creator", "admin")
def update_channel(channel_id: str):
    """Update a podcast channel owned by the current creator (or admin)."""
    user = get_current_user()
    existing = db.fetch_one(
        """
        SELECT ma_kenh AS channel_id, ma_creator AS creator_id, tieu_de_kenh AS title,
               mo_ta AS description, the_loai AS category, anh_bia AS cover_image_url
        FROM KenhPodcast WHERE ma_kenh = %s
        """,
        (channel_id,),
    )
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
        UPDATE KenhPodcast
        SET tieu_de_kenh = %s, mo_ta = %s, the_loai = %s, anh_bia = %s
        WHERE ma_kenh = %s
        """,
        (title, description, category, cover_image_url, channel_id),
    )
    updated = db.fetch_one(
        """
        SELECT ma_kenh AS channel_id, ma_creator AS creator_id, tieu_de_kenh AS title,
               mo_ta AS description, the_loai AS category, anh_bia AS cover_image_url,
               ngay_tao AS created_at, ngay_cap_nhat AS updated_at
        FROM KenhPodcast WHERE ma_kenh = %s
        """,
        (channel_id,),
    )
    return success(updated, message="Cập nhật kênh Podcast thành công.")


@content_bp.delete("/channels/<channel_id>")
@roles_required("creator", "admin")
def delete_channel(channel_id: str):
    """Delete a podcast channel owned by the current creator (or admin)."""
    user = get_current_user()
    existing = db.fetch_one("SELECT ma_kenh AS channel_id, ma_creator AS creator_id FROM KenhPodcast WHERE ma_kenh = %s", (channel_id,))
    if not existing:
        raise AppError("Không tìm thấy kênh Podcast.", status_code=404)
    if user["role"] != "admin" and existing["creator_id"] != user.get("creator_id"):
        raise AppError("Bạn không có quyền xóa kênh này.", status_code=403)

    db.execute("DELETE FROM KenhPodcast WHERE ma_kenh = %s", (channel_id,))
    return success({"deleted_channel_id": channel_id}, message="Đã xóa kênh Podcast.")


@content_bp.get("/episodes")
def list_episodes():
    """Search and filter episodes (supports duration range for Q1 and keyword search)."""
    q = request.args.get("q", "").strip()
    channel_id = request.args.get("channel_id", "").strip()
    category = request.args.get("category", "").strip()
    status = request.args.get("status", "").strip().lower()
    min_duration = request.args.get("min_duration", type=int)
    max_duration = request.args.get("max_duration", type=int)

    where_clauses = []
    params: list = []

    if q:
        like = f"%{q}%"
        where_clauses.append("(e.tieu_de_tap LIKE %s OR e.mo_ta LIKE %s OR ch.tieu_de_kenh LIKE %s)")
        params.extend([like, like, like])
    if channel_id:
        where_clauses.append("e.ma_kenh = %s")
        params.append(channel_id)
    if category:
        where_clauses.append("ch.the_loai = %s")
        params.append(category)
    if status:
        vi_status = _EP_STATUS_TO_VI.get(status, status)
        where_clauses.append("e.trang_thai = %s")
        params.append(vi_status)
    if min_duration is not None:
        where_clauses.append("e.thoi_luong_giay >= %s")
        params.append(min_duration)
    if max_duration is not None:
        where_clauses.append("e.thoi_luong_giay <= %s")
        params.append(max_duration)

    where_sql = f"WHERE {' AND '.join(where_clauses)}" if where_clauses else ""

    rows = db.fetch_all(
        f"""
        SELECT e.ma_tap AS episode_id,
               e.ma_kenh AS channel_id,
               e.tieu_de_tap AS title,
               e.mo_ta AS description,
               e.duong_dan_audio AS audio_url,
               e.thoi_luong_giay AS duration_seconds,
               SEC_TO_TIME(e.thoi_luong_giay) AS duration_formatted,
               e.ngay_phat_hanh AS published_at,
               {_EP_STATUS_SQL} AS status,
               e.ngay_tao AS created_at,
               ch.tieu_de_kenh AS channel_title,
               ch.the_loai AS category,
               ch.ma_creator AS creator_id,
               cr.ten_hien_thi AS creator_name,
               COUNT(DISTINCT lh.ma_lich_su) AS listen_count,
               COALESCE(ROUND(AVG(r.so_sao), 2), 0) AS avg_rating,
               COUNT(DISTINCT sl.ma_hop_dong) AS ad_contract_count
        FROM TapPodcast e
        JOIN KenhPodcast ch ON e.ma_kenh = ch.ma_kenh
        JOIN NhaSangTao cr ON ch.ma_creator = cr.ma_creator
        LEFT JOIN LichSuNghe lh ON e.ma_tap = lh.ma_tap
        LEFT JOIN DanhGia r ON e.ma_tap = r.ma_tap
        LEFT JOIN ViTriQC sl ON e.ma_tap = sl.ma_tap
        {where_sql}
        GROUP BY e.ma_tap, e.ma_kenh, e.tieu_de_tap, e.mo_ta, e.duong_dan_audio,
                 e.thoi_luong_giay, e.ngay_phat_hanh, e.trang_thai, e.ngay_tao,
                 ch.tieu_de_kenh, ch.the_loai, ch.ma_creator, cr.ten_hien_thi
        ORDER BY e.ngay_phat_hanh DESC, e.ma_tap DESC
        """,
        params,
    )
    return success(rows)


@content_bp.get("/episodes/<episode_id>")
def get_episode(episode_id: str):
    """Get full details for a single episode including attached ad slots."""
    ep = db.fetch_one(
        f"""
        SELECT e.ma_tap AS episode_id,
               e.ma_kenh AS channel_id,
               e.tieu_de_tap AS title,
               e.mo_ta AS description,
               e.duong_dan_audio AS audio_url,
               e.thoi_luong_giay AS duration_seconds,
               e.ngay_phat_hanh AS published_at,
               {_EP_STATUS_SQL} AS status,
               e.ngay_tao AS created_at,
               ch.tieu_de_kenh AS channel_title,
               ch.the_loai AS category,
               ch.ma_creator AS creator_id,
               cr.ten_hien_thi AS creator_name,
               COUNT(DISTINCT lh.ma_lich_su) AS listen_count,
               COALESCE(ROUND(AVG(r.so_sao), 2), 0) AS avg_rating
        FROM TapPodcast e
        JOIN KenhPodcast ch ON e.ma_kenh = ch.ma_kenh
        JOIN NhaSangTao cr ON ch.ma_creator = cr.ma_creator
        LEFT JOIN LichSuNghe lh ON e.ma_tap = lh.ma_tap
        LEFT JOIN DanhGia r ON e.ma_tap = r.ma_tap
        WHERE e.ma_tap = %s
        GROUP BY e.ma_tap, e.ma_kenh, e.tieu_de_tap, e.mo_ta, e.duong_dan_audio,
                 e.thoi_luong_giay, e.ngay_phat_hanh, e.trang_thai, e.ngay_tao,
                 ch.tieu_de_kenh, ch.the_loai, ch.ma_creator, cr.ten_hien_thi
        """,
        (episode_id,),
    )
    if not ep:
        raise AppError("Không tìm thấy tập Podcast.", status_code=404)

    slots = db.fetch_all(
        """
        SELECT s.ma_vi_tri AS slot_id,
               CASE s.vi_tri
                   WHEN 'dau_tap' THEN 'pre-roll'
                   WHEN 'cuoi_tap' THEN 'post-roll'
                   ELSE 'mid-roll'
               END AS slot_position,
               s.giay_bat_dau AS start_offset_seconds,
               s.trang_thai AS status,
               ac.ma_hop_dong AS contract_id,
               ac.so_hop_dong AS contract_code,
               a.ma_quang_cao AS ad_id,
               a.nha_quang_cao AS advertiser_name,
               a.tieu_de_qc AS ad_title,
               a.thoi_luong_giay AS ad_duration_seconds
        FROM ViTriQC s
        JOIN HopDongQC ac ON s.ma_hop_dong = ac.ma_hop_dong
        JOIN QuangCao a ON ac.ma_quang_cao = a.ma_quang_cao
        WHERE s.ma_tap = %s
        ORDER BY s.giay_bat_dau ASC
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

    channel_id = str(data["channel_id"]).strip()
    duration_seconds = int(data["duration_seconds"])
    status_en = str(data.get("status", "published")).strip().lower()
    status_vi = _EP_STATUS_TO_VI.get(status_en, status_en)
    if status_vi not in ("nhap", "da_phat_hanh", "luu_tru"):
        raise AppError("Trạng thái episode phải là draft, published hoặc archived.", status_code=400)
    if duration_seconds <= 0:
        raise AppError("Thời lượng tập (duration_seconds) phải lớn hơn 0.", status_code=400)

    channel = db.fetch_one("SELECT ma_kenh AS channel_id, ma_creator AS creator_id FROM KenhPodcast WHERE ma_kenh = %s", (channel_id,))
    if not channel:
        raise AppError("Kênh Podcast không tồn tại.", status_code=404)
    if user["role"] != "admin" and channel["creator_id"] != user.get("creator_id"):
        raise AppError("Bạn không có quyền thêm tập vào kênh này.", status_code=403)

    episode_id = db.next_id("EP", "TapPodcast", "ma_tap")
    db.execute(
        """
        INSERT INTO TapPodcast (ma_tap, ma_kenh, tieu_de_tap, mo_ta, duong_dan_audio, thoi_luong_giay, trang_thai, ngay_phat_hanh)
        VALUES (%s, %s, %s, %s, %s, %s, %s, CASE WHEN %s = 'da_phat_hanh' THEN NOW() ELSE NULL END)
        """,
        (
            episode_id,
            channel_id,
            str(data["title"]).strip(),
            str(data.get("description") or "").strip() or None,
            str(data["audio_url"]).strip(),
            duration_seconds,
            status_vi,
            status_vi,
        ),
    )
    row = db.fetch_one(
        f"""
        SELECT e.ma_tap AS episode_id, e.ma_kenh AS channel_id, e.tieu_de_tap AS title,
               e.mo_ta AS description, e.duong_dan_audio AS audio_url,
               e.thoi_luong_giay AS duration_seconds, e.ngay_phat_hanh AS published_at,
               {_EP_STATUS_SQL} AS status, e.ngay_tao AS created_at
        FROM TapPodcast e WHERE e.ma_tap = %s
        """,
        (episode_id,),
    )
    return success(row, message="Tạo tập Podcast thành công.", status=201)


@content_bp.put("/episodes/<episode_id>")
@roles_required("creator", "admin")
def update_episode(episode_id: str):
    """Update an existing episode (respecting business rule constraints on duration_seconds)."""
    user = get_current_user()
    existing = db.fetch_one(
        f"""
        SELECT e.ma_tap AS episode_id, e.ma_kenh AS channel_id, e.tieu_de_tap AS title,
               e.mo_ta AS description, e.duong_dan_audio AS audio_url,
               e.thoi_luong_giay AS duration_seconds, {_EP_STATUS_SQL} AS status,
               ch.ma_creator AS creator_id
        FROM TapPodcast e
        JOIN KenhPodcast ch ON e.ma_kenh = ch.ma_kenh
        WHERE e.ma_tap = %s
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

    if duration_seconds < 1200 and existing["duration_seconds"] >= 1200:
        slot_stats = db.fetch_one(
            "SELECT COUNT(DISTINCT ma_hop_dong) AS distinct_contracts FROM ViTriQC WHERE ma_tap = %s",
            (episode_id,),
        )
        if slot_stats and slot_stats["distinct_contracts"] > 3:
            raise AppError(
                "Không thể giảm thời lượng Episode xuống dưới 20 phút vì đã có hơn 3 hợp đồng quảng cáo.",
                status_code=400,
            )

    status_in = str(data.get("status", existing["status"])).strip().lower()
    status_vi = _EP_STATUS_TO_VI.get(status_in, status_in)
    if status_vi not in ("nhap", "da_phat_hanh", "luu_tru"):
        raise AppError("Trạng thái episode không hợp lệ.", status_code=400)

    db.execute(
        """
        UPDATE TapPodcast
        SET tieu_de_tap = %s,
            mo_ta = %s,
            duong_dan_audio = %s,
            thoi_luong_giay = %s,
            trang_thai = %s,
            ngay_phat_hanh = CASE
                WHEN %s = 'da_phat_hanh' AND ngay_phat_hanh IS NULL THEN NOW()
                ELSE ngay_phat_hanh
            END
        WHERE ma_tap = %s
        """,
        (title, description, audio_url, duration_seconds, status_vi, status_vi, episode_id),
    )
    updated = db.fetch_one(
        f"""
        SELECT e.ma_tap AS episode_id, e.ma_kenh AS channel_id, e.tieu_de_tap AS title,
               e.mo_ta AS description, e.duong_dan_audio AS audio_url,
               e.thoi_luong_giay AS duration_seconds, e.ngay_phat_hanh AS published_at,
               {_EP_STATUS_SQL} AS status, e.ngay_tao AS created_at
        FROM TapPodcast e WHERE e.ma_tap = %s
        """,
        (episode_id,),
    )
    return success(updated, message="Cập nhật tập Podcast thành công.")


@content_bp.delete("/episodes/<episode_id>")
@roles_required("creator", "admin")
def delete_episode(episode_id: str):
    """Delete an episode owned by the authenticated creator (or admin)."""
    user = get_current_user()
    existing = db.fetch_one(
        """
        SELECT e.ma_tap AS episode_id, ch.ma_creator AS creator_id
        FROM TapPodcast e
        JOIN KenhPodcast ch ON e.ma_kenh = ch.ma_kenh
        WHERE e.ma_tap = %s
        """,
        (episode_id,),
    )
    if not existing:
        raise AppError("Không tìm thấy tập Podcast.", status_code=404)
    if user["role"] != "admin" and existing["creator_id"] != user.get("creator_id"):
        raise AppError("Bạn không có quyền xóa tập này.", status_code=403)

    db.execute("DELETE FROM TapPodcast WHERE ma_tap = %s", (episode_id,))
    return success({"deleted_episode_id": episode_id}, message="Đã xóa tập Podcast.")
