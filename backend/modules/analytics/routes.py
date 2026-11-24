"""Module 03: Advertisement, Donations & Business Analytics RESTful API Blueprint (Vietnamese Schema)."""

from flask import Blueprint, request

from common.auth import get_current_user, login_required, roles_required
from common.errors import AppError
from common.response import success
from config import db

analytics_bp = Blueprint("analytics", __name__, url_prefix="/api/analytics")

_AD_STATUS_TO_VI = {"active": "hoat_dong", "paused": "tam_dung", "archived": "luu_tru"}
_CONTRACT_STATUS_TO_VI = {"draft": "nhap", "active": "hieu_luc", "completed": "hoan_thanh", "cancelled": "da_huy"}
_SLOT_POS_TO_VI = {"pre-roll": "dau_tap", "mid-roll": "giua_tap", "post-roll": "cuoi_tap"}
_SLOT_STATUS_TO_VI = {"scheduled": "da_len_lich", "active": "hoat_dong", "paused": "tam_dung"}


def _json_body() -> dict:
    data = request.get_json(silent=True)
    if not isinstance(data, dict):
        raise AppError("Request body phải là JSON hợp lệ.", status_code=400, code="INVALID_JSON")
    return data


def _require_fields(data: dict, *fields: str) -> None:
    missing = [f for f in fields if data.get(f) is None or str(data.get(f)).strip() == ""]
    if missing:
        raise AppError(f"Thiếu thông tin bắt buộc: {', '.join(missing)}.", status_code=400)


# -------------------------------------------------------------------
# Advertisements CRUD (QuangCao)
# -------------------------------------------------------------------

@analytics_bp.get("/ads")
def list_ads():
    """List advertisements."""
    status = request.args.get("status", "").strip().lower()
    select_cols = """
        ma_quang_cao AS ad_id, nha_quang_cao AS advertiser_name, tieu_de_qc AS title,
        mo_ta AS description, audio_qc AS ad_audio_url, link_dich AS target_url,
        thoi_luong_giay AS duration_seconds,
        CASE trang_thai WHEN 'hoat_dong' THEN 'active' WHEN 'tam_dung' THEN 'paused' ELSE 'archived' END AS status,
        ngay_tao AS created_at
    """
    if status:
        vi_status = _AD_STATUS_TO_VI.get(status, status)
        rows = db.fetch_all(f"SELECT {select_cols} FROM QuangCao WHERE trang_thai = %s ORDER BY ma_quang_cao DESC", (vi_status,))
    else:
        rows = db.fetch_all(f"SELECT {select_cols} FROM QuangCao ORDER BY ma_quang_cao DESC")
    return success(rows)


@analytics_bp.post("/ads")
@roles_required("creator", "admin")
def create_ad():
    """Create a new advertisement campaign."""
    data = _json_body()
    _require_fields(data, "advertiser_name", "title", "duration_seconds")
    duration = int(data["duration_seconds"])
    if duration <= 0:
        raise AppError("Thời lượng quảng cáo phải lớn hơn 0.", status_code=400)
    status_in = str(data.get("status", "active")).strip().lower()
    if status_in not in _AD_STATUS_TO_VI:
        raise AppError("Trạng thái quảng cáo không hợp lệ.", status_code=400)

    ad_id = db.next_id("QC", "QuangCao", "ma_quang_cao")
    db.execute(
        """
        INSERT INTO QuangCao (ma_quang_cao, nha_quang_cao, tieu_de_qc, mo_ta, audio_qc, link_dich, thoi_luong_giay, trang_thai)
        VALUES (%s, %s, %s, %s, %s, %s, %s, %s)
        """,
        (
            ad_id,
            str(data["advertiser_name"]).strip(),
            str(data["title"]).strip(),
            str(data.get("description") or "").strip() or None,
            data.get("ad_audio_url"),
            data.get("target_url"),
            duration,
            _AD_STATUS_TO_VI[status_in],
        ),
    )
    row = db.fetch_one(
        """
        SELECT ma_quang_cao AS ad_id, nha_quang_cao AS advertiser_name, tieu_de_qc AS title,
               mo_ta AS description, audio_qc AS ad_audio_url, link_dich AS target_url,
               thoi_luong_giay AS duration_seconds,
               CASE trang_thai WHEN 'hoat_dong' THEN 'active' WHEN 'tam_dung' THEN 'paused' ELSE 'archived' END AS status,
               ngay_tao AS created_at
        FROM QuangCao WHERE ma_quang_cao = %s
        """,
        (ad_id,),
    )
    return success(row, message="Tạo quảng cáo thành công.", status=201)


@analytics_bp.put("/ads/<ad_id>")
@roles_required("creator", "admin")
def update_ad(ad_id: str):
    """Update an advertisement campaign."""
    existing = db.fetch_one(
        """
        SELECT ma_quang_cao AS ad_id, nha_quang_cao AS advertiser_name, tieu_de_qc AS title,
               mo_ta AS description, link_dich AS target_url, thoi_luong_giay AS duration_seconds,
               trang_thai AS trang_thai_vi
        FROM QuangCao WHERE ma_quang_cao = %s
        """,
        (ad_id,),
    )
    if not existing:
        raise AppError("Không tìm thấy quảng cáo.", status_code=404)
    data = _json_body()
    status_in = str(data.get("status") or "").strip().lower()
    trang_thai_vi = _AD_STATUS_TO_VI.get(status_in, existing["trang_thai_vi"])
    db.execute(
        """
        UPDATE QuangCao
        SET nha_quang_cao = %s, tieu_de_qc = %s, mo_ta = %s, link_dich = %s,
            thoi_luong_giay = %s, trang_thai = %s
        WHERE ma_quang_cao = %s
        """,
        (
            str(data.get("advertiser_name") or existing["advertiser_name"]).strip(),
            str(data.get("title") or existing["title"]).strip(),
            data.get("description", existing["description"]),
            data.get("target_url", existing["target_url"]),
            int(data.get("duration_seconds", existing["duration_seconds"])),
            trang_thai_vi,
            ad_id,
        ),
    )
    row = db.fetch_one(
        """
        SELECT ma_quang_cao AS ad_id, nha_quang_cao AS advertiser_name, tieu_de_qc AS title,
               mo_ta AS description, audio_qc AS ad_audio_url, link_dich AS target_url,
               thoi_luong_giay AS duration_seconds,
               CASE trang_thai WHEN 'hoat_dong' THEN 'active' WHEN 'tam_dung' THEN 'paused' ELSE 'archived' END AS status,
               ngay_tao AS created_at
        FROM QuangCao WHERE ma_quang_cao = %s
        """,
        (ad_id,),
    )
    return success(row, message="Cập nhật quảng cáo thành công.")


# -------------------------------------------------------------------
# AdContracts CRUD (HopDongQC)
# -------------------------------------------------------------------

@analytics_bp.get("/contracts")
def list_contracts():
    """List ad contracts joined with ad and creator info."""
    creator_id = request.args.get("creator_id", "").strip()
    where_sql = "WHERE ac.ma_creator = %s" if creator_id else ""
    params = (creator_id,) if creator_id else ()
    rows = db.fetch_all(
        f"""
        SELECT ac.ma_hop_dong AS contract_id,
               ac.ma_quang_cao AS ad_id,
               ac.ma_creator AS creator_id,
               ac.so_hop_dong AS contract_code,
               ac.gia_tri_hd AS contract_value,
               ac.don_gia_cpm AS cpm_rate,
               ac.ngay_bat_dau AS start_date,
               ac.ngay_ket_thuc AS end_date,
               CASE ac.trang_thai
                   WHEN 'hieu_luc' THEN 'active'
                   WHEN 'hoan_thanh' THEN 'completed'
                   WHEN 'da_huy' THEN 'cancelled'
                   ELSE 'draft'
               END AS status,
               ac.ngay_tao AS created_at,
               a.nha_quang_cao AS advertiser_name,
               a.tieu_de_qc AS ad_title,
               a.thoi_luong_giay AS ad_duration_seconds,
               cr.ten_hien_thi AS creator_name,
               COUNT(DISTINCT sl.ma_vi_tri) AS assigned_slots_count,
               COALESCE(SUM(ar.so_tien), 0) AS realized_revenue
        FROM HopDongQC ac
        JOIN QuangCao a ON ac.ma_quang_cao = a.ma_quang_cao
        JOIN NhaSangTao cr ON ac.ma_creator = cr.ma_creator
        LEFT JOIN ViTriQC sl ON ac.ma_hop_dong = sl.ma_hop_dong
        LEFT JOIN DoanhThuQC ar ON ac.ma_hop_dong = ar.ma_hop_dong
        {where_sql}
        GROUP BY ac.ma_hop_dong, ac.ma_quang_cao, ac.ma_creator, ac.so_hop_dong,
                 ac.gia_tri_hd, ac.don_gia_cpm, ac.ngay_bat_dau, ac.ngay_ket_thuc,
                 ac.trang_thai, ac.ngay_tao,
                 a.nha_quang_cao, a.tieu_de_qc, a.thoi_luong_giay, cr.ten_hien_thi
        ORDER BY ac.ma_hop_dong DESC
        """,
        params,
    )
    return success(rows)


@analytics_bp.post("/contracts")
@roles_required("creator", "admin")
def create_contract():
    """Create a commercial ad contract between an advertisement and a creator."""
    user = get_current_user()
    data = _json_body()
    _require_fields(data, "ad_id", "contract_code", "contract_value", "start_date", "end_date")

    creator_id = str(data.get("creator_id") or user.get("creator_id") or "").strip()
    if not creator_id:
        raise AppError("Thiếu creator_id cho hợp đồng.", status_code=400)
    if user["role"] != "admin" and creator_id != user.get("creator_id"):
        raise AppError("Bạn chỉ có thể tạo hợp đồng cho Creator của chính mình.", status_code=403)

    status_in = str(data.get("status", "active")).strip().lower()
    trang_thai_vi = _CONTRACT_STATUS_TO_VI.get(status_in, status_in)
    contract_id = db.next_id("HD", "HopDongQC", "ma_hop_dong")

    db.execute(
        """
        INSERT INTO HopDongQC (ma_hop_dong, ma_quang_cao, ma_creator, so_hop_dong, gia_tri_hd, don_gia_cpm, ngay_bat_dau, ngay_ket_thuc, trang_thai)
        VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s)
        """,
        (
            contract_id,
            str(data["ad_id"]).strip(),
            creator_id,
            str(data["contract_code"]).strip(),
            float(data["contract_value"]),
            float(data.get("cpm_rate", 0)),
            str(data["start_date"]).strip(),
            str(data["end_date"]).strip(),
            trang_thai_vi,
        ),
    )
    row = db.fetch_one(
        """
        SELECT ma_hop_dong AS contract_id, ma_quang_cao AS ad_id, ma_creator AS creator_id,
               so_hop_dong AS contract_code, gia_tri_hd AS contract_value, don_gia_cpm AS cpm_rate,
               ngay_bat_dau AS start_date, ngay_ket_thuc AS end_date,
               CASE trang_thai WHEN 'hieu_luc' THEN 'active' WHEN 'hoan_thanh' THEN 'completed' WHEN 'da_huy' THEN 'cancelled' ELSE 'draft' END AS status,
               ngay_tao AS created_at
        FROM HopDongQC WHERE ma_hop_dong = %s
        """,
        (contract_id,),
    )
    return success(row, message="Tạo hợp đồng quảng cáo thành công.", status=201)


# -------------------------------------------------------------------
# AdSlots CRUD (ViTriQC — Business Rules enforced in Backend)
# -------------------------------------------------------------------

@analytics_bp.get("/slots")
def list_slots():
    """List ad slot placements across episodes."""
    episode_id = request.args.get("episode_id", "").strip()
    where_sql = "WHERE s.ma_tap = %s" if episode_id else ""
    params = (episode_id,) if episode_id else ()
    rows = db.fetch_all(
        f"""
        SELECT s.ma_vi_tri AS slot_id,
               s.ma_hop_dong AS contract_id,
               s.ma_tap AS episode_id,
               CASE s.vi_tri WHEN 'dau_tap' THEN 'pre-roll' WHEN 'cuoi_tap' THEN 'post-roll' ELSE 'mid-roll' END AS slot_position,
               s.giay_bat_dau AS start_offset_seconds,
               CASE s.trang_thai WHEN 'da_len_lich' THEN 'scheduled' WHEN 'tam_dung' THEN 'paused' ELSE 'active' END AS status,
               s.ngay_tao AS created_at,
               e.tieu_de_tap AS episode_title,
               e.thoi_luong_giay AS episode_duration_seconds,
               ch.ma_kenh AS channel_id,
               ch.tieu_de_kenh AS channel_title,
               ac.so_hop_dong AS contract_code,
               ac.ma_creator AS creator_id,
               a.nha_quang_cao AS advertiser_name,
               a.tieu_de_qc AS ad_title
        FROM ViTriQC s
        JOIN TapPodcast e ON s.ma_tap = e.ma_tap
        JOIN KenhPodcast ch ON e.ma_kenh = ch.ma_kenh
        JOIN HopDongQC ac ON s.ma_hop_dong = ac.ma_hop_dong
        JOIN QuangCao a ON ac.ma_quang_cao = a.ma_quang_cao
        {where_sql}
        ORDER BY s.ma_tap ASC, s.giay_bat_dau ASC
        """,
        params,
    )
    return success(rows)


@analytics_bp.post("/slots")
@roles_required("creator", "admin")
def create_slot():
    """Assign an ad contract to an episode slot (business rules enforced in Backend)."""
    user = get_current_user()
    data = _json_body()
    _require_fields(data, "contract_id", "episode_id")

    contract_id = str(data["contract_id"]).strip()
    episode_id = str(data["episode_id"]).strip()
    slot_position = str(data.get("slot_position", "mid-roll")).strip().lower()
    if slot_position not in _SLOT_POS_TO_VI:
        raise AppError("Vị trí quảng cáo phải là pre-roll, mid-roll hoặc post-roll.", status_code=400)

    offset = int(data.get("start_offset_seconds", 0))
    status_in = str(data.get("status", "active")).strip().lower()
    trang_thai_vi = _SLOT_STATUS_TO_VI.get(status_in, status_in)

    ep_info = db.fetch_one(
        """
        SELECT e.thoi_luong_giay AS duration_seconds, ch.ma_creator AS creator_id
        FROM TapPodcast e
        JOIN KenhPodcast ch ON e.ma_kenh = ch.ma_kenh
        WHERE e.ma_tap = %s
        """,
        (episode_id,),
    )
    if not ep_info:
        raise AppError("Episode không tồn tại.", status_code=404)

    if user["role"] != "admin" and ep_info["creator_id"] != user.get("creator_id"):
        raise AppError("Bạn không có quyền gắn quảng cáo vào Episode của Creator khác.", status_code=403)

    contract_info = db.fetch_one(
        "SELECT ma_hop_dong AS contract_id, ma_creator AS creator_id FROM HopDongQC WHERE ma_hop_dong = %s",
        (contract_id,),
    )
    if not contract_info:
        raise AppError("Hợp đồng quảng cáo không tồn tại.", status_code=404)

    if ep_info["creator_id"] != contract_info["creator_id"]:
        raise AppError("Hợp đồng quảng cáo chỉ được gắn vào Episode thuộc cùng Creator.", status_code=400)

    if offset < 0 or offset >= ep_info["duration_seconds"]:
        raise AppError("Vị trí quảng cáo (start_offset_seconds) vượt quá thời lượng Episode.", status_code=400)

    if ep_info["duration_seconds"] < 1200:
        slot_stats = db.fetch_one(
            """
            SELECT COUNT(DISTINCT ma_hop_dong) AS distinct_contracts,
                   COALESCE(MAX(CASE WHEN ma_hop_dong = %s THEN 1 ELSE 0 END), 0) AS already_attached
            FROM ViTriQC
            WHERE ma_tap = %s
            """,
            (contract_id, episode_id),
        )
        if slot_stats and slot_stats["already_attached"] == 0 and slot_stats["distinct_contracts"] >= 3:
            raise AppError(
                "Episode dưới 20 phút (< 1200s) chỉ được gắn tối đa 3 hợp đồng quảng cáo.",
                status_code=400,
            )

    slot_id = db.next_id("VT", "ViTriQC", "ma_vi_tri")
    db.execute(
        """
        INSERT INTO ViTriQC (ma_vi_tri, ma_hop_dong, ma_tap, vi_tri, giay_bat_dau, trang_thai)
        VALUES (%s, %s, %s, %s, %s, %s)
        """,
        (slot_id, contract_id, episode_id, _SLOT_POS_TO_VI[slot_position], offset, trang_thai_vi),
    )
    row = db.fetch_one(
        """
        SELECT ma_vi_tri AS slot_id, ma_hop_dong AS contract_id, ma_tap AS episode_id,
               CASE vi_tri WHEN 'dau_tap' THEN 'pre-roll' WHEN 'cuoi_tap' THEN 'post-roll' ELSE 'mid-roll' END AS slot_position,
               giay_bat_dau AS start_offset_seconds,
               CASE trang_thai WHEN 'da_len_lich' THEN 'scheduled' WHEN 'tam_dung' THEN 'paused' ELSE 'active' END AS status,
               ngay_tao AS created_at
        FROM ViTriQC WHERE ma_vi_tri = %s
        """,
        (slot_id,),
    )
    return success(row, message="Đã gắn quảng cáo vào Episode thành công.", status=201)


@analytics_bp.delete("/slots/<slot_id>")
@roles_required("creator", "admin")
def delete_slot(slot_id: str):
    """Remove an ad slot placement."""
    user = get_current_user()
    existing = db.fetch_one(
        """
        SELECT s.ma_vi_tri AS slot_id, ch.ma_creator AS creator_id
        FROM ViTriQC s
        JOIN TapPodcast e ON s.ma_tap = e.ma_tap
        JOIN KenhPodcast ch ON e.ma_kenh = ch.ma_kenh
        WHERE s.ma_vi_tri = %s
        """,
        (slot_id,),
    )
    if not existing:
        raise AppError("Không tìm thấy AdSlot.", status_code=404)
    if user["role"] != "admin" and existing["creator_id"] != user.get("creator_id"):
        raise AppError("Bạn không có quyền xóa AdSlot này.", status_code=403)

    db.execute("DELETE FROM ViTriQC WHERE ma_vi_tri = %s", (slot_id,))
    return success({"deleted_slot_id": slot_id}, message="Đã gỡ AdSlot khỏi Episode.")


# -------------------------------------------------------------------
# AdRevenue & Donations (DoanhThuQC & UngHo)
# -------------------------------------------------------------------

@analytics_bp.get("/revenue")
def list_revenue():
    """List ad revenue entries joined with contracts and creators."""
    rows = db.fetch_all(
        """
        SELECT ar.ma_doanh_thu AS revenue_id,
               ar.ma_hop_dong AS contract_id,
               ar.ma_vi_tri AS slot_id,
               ar.ngay_ghi_nhan AS revenue_date,
               ar.luot_hien_thi AS impressions,
               ar.so_tien AS amount,
               ar.ghi_chu AS notes,
               ar.ngay_tao AS created_at,
               ac.so_hop_dong AS contract_code,
               cr.ma_creator AS creator_id,
               cr.ten_hien_thi AS creator_name,
               a.nha_quang_cao AS advertiser_name,
               a.tieu_de_qc AS ad_title
        FROM DoanhThuQC ar
        JOIN HopDongQC ac ON ar.ma_hop_dong = ac.ma_hop_dong
        JOIN NhaSangTao cr ON ac.ma_creator = cr.ma_creator
        JOIN QuangCao a ON ac.ma_quang_cao = a.ma_quang_cao
        ORDER BY ar.ngay_ghi_nhan DESC, ar.ma_doanh_thu DESC
        """
    )
    return success(rows)


@analytics_bp.post("/revenue")
@roles_required("creator", "admin")
def create_revenue():
    """Record a new ad revenue entry."""
    data = _json_body()
    _require_fields(data, "contract_id", "revenue_date", "amount")
    rev_id = db.next_id("DT", "DoanhThuQC", "ma_doanh_thu")
    db.execute(
        """
        INSERT INTO DoanhThuQC (ma_doanh_thu, ma_hop_dong, ma_vi_tri, ngay_ghi_nhan, luot_hien_thi, so_tien, ghi_chu)
        VALUES (%s, %s, %s, %s, %s, %s, %s)
        """,
        (
            rev_id,
            str(data["contract_id"]).strip(),
            str(data["slot_id"]).strip() if data.get("slot_id") else None,
            str(data["revenue_date"]).strip(),
            int(data.get("impressions", 0)),
            float(data["amount"]),
            str(data.get("notes") or "").strip() or None,
        ),
    )
    row = db.fetch_one(
        """
        SELECT ma_doanh_thu AS revenue_id, ma_hop_dong AS contract_id, ma_vi_tri AS slot_id,
               ngay_ghi_nhan AS revenue_date, luot_hien_thi AS impressions, so_tien AS amount,
               ghi_chu AS notes, ngay_tao AS created_at
        FROM DoanhThuQC WHERE ma_doanh_thu = %s
        """,
        (rev_id,),
    )
    return success(row, message="Đã ghi nhận doanh thu quảng cáo.", status=201)


@analytics_bp.get("/donations")
def list_donations():
    """List donation history."""
    rows = db.fetch_all(
        """
        SELECT d.ma_ung_ho AS donation_id,
               d.ma_nguoi_ung_ho AS donor_user_id,
               d.ma_creator AS creator_id,
               d.so_tien_ung_ho AS amount,
               d.loi_nhan AS message,
               d.ngay_ung_ho AS donated_at,
               u.ten_dang_nhap AS donor_username,
               u.ho_ten AS donor_name,
               cr.ten_hien_thi AS creator_name
        FROM UngHo d
        JOIN NguoiDung u ON d.ma_nguoi_ung_ho = u.ma_nguoi_dung
        JOIN NhaSangTao cr ON d.ma_creator = cr.ma_creator
        ORDER BY d.ngay_ung_ho DESC, d.ma_ung_ho DESC
        """
    )
    return success(rows)


@analytics_bp.post("/donations")
@login_required
def create_donation():
    """Record a financial donation from the authenticated user to a creator."""
    user = get_current_user()
    data = _json_body()
    _require_fields(data, "creator_id", "amount")
    amount = float(data["amount"])
    if amount <= 0:
        raise AppError("Số tiền ủng hộ phải lớn hơn 0.", status_code=400)

    donation_id = db.next_id("UH", "UngHo", "ma_ung_ho")
    db.execute(
        """
        INSERT INTO UngHo (ma_ung_ho, ma_nguoi_ung_ho, ma_creator, so_tien_ung_ho, loi_nhan)
        VALUES (%s, %s, %s, %s, %s)
        """,
        (
            donation_id,
            user["user_id"],
            str(data["creator_id"]).strip(),
            amount,
            str(data.get("message") or "").strip() or None,
        ),
    )
    row = db.fetch_one(
        """
        SELECT d.ma_ung_ho AS donation_id, d.ma_nguoi_ung_ho AS donor_user_id,
               d.ma_creator AS creator_id,
               d.so_tien_ung_ho AS amount, d.loi_nhan AS message, d.ngay_ung_ho AS donated_at,
               u.ten_dang_nhap AS donor_username, u.ho_ten AS donor_name,
               cr.ten_hien_thi AS creator_name
        FROM UngHo d
        JOIN NguoiDung u ON d.ma_nguoi_ung_ho = u.ma_nguoi_dung
        JOIN NhaSangTao cr ON d.ma_creator = cr.ma_creator
        WHERE d.ma_ung_ho = %s
        """,
        (donation_id,),
    )
    return success(row, message="Cảm ơn bạn đã ủng hộ Creator!", status=201)


# -------------------------------------------------------------------
# Analytics Reports & Required SQL Queries Q1..Q8 Runner
# -------------------------------------------------------------------

_QUERY_SPECS = {
    "Q1": {
        "id": "Q1",
        "owner": "Mạnh",
        "title": "Episodes thời lượng 15–30 phút thuộc Channel cụ thể",
        "concepts": "JOIN, WHERE, BETWEEN, SEC_TO_TIME",
        "sql": """
SELECT e.ma_tap AS episode_id, c.tieu_de_kenh AS channel_name, e.tieu_de_tap AS episode_title,
       e.thoi_luong_giay AS duration_seconds, SEC_TO_TIME(e.thoi_luong_giay) AS duration_formatted,
       e.ngay_phat_hanh AS published_at,
       CASE e.trang_thai WHEN 'da_phat_hanh' THEN 'published' WHEN 'luu_tru' THEN 'archived' ELSE 'draft' END AS status
FROM TapPodcast e
JOIN KenhPodcast c ON e.ma_kenh = c.ma_kenh
WHERE e.ma_kenh = %s
  AND e.trang_thai = 'da_phat_hanh'
  AND e.thoi_luong_giay BETWEEN 900 AND 1800
ORDER BY e.thoi_luong_giay ASC
""",
    },
    "Q2": {
        "id": "Q2",
        "owner": "Quang",
        "title": "Các quảng cáo xuất hiện trong EP99",
        "concepts": "Multi-table JOIN (4 bảng), LIKE",
        "sql": """
SELECT e.ma_tap AS episode_id, e.tieu_de_tap AS episode_title,
       CASE s.vi_tri WHEN 'dau_tap' THEN 'pre-roll' WHEN 'cuoi_tap' THEN 'post-roll' ELSE 'mid-roll' END AS slot_position,
       s.giay_bat_dau AS start_offset_seconds, SEC_TO_TIME(s.giay_bat_dau) AS offset_formatted,
       ac.so_hop_dong AS contract_code, a.ma_quang_cao AS ad_id, a.nha_quang_cao AS advertiser_name,
       a.tieu_de_qc AS ad_title, a.thoi_luong_giay AS ad_duration_seconds
FROM TapPodcast e
JOIN ViTriQC s ON e.ma_tap = s.ma_tap
JOIN HopDongQC ac ON s.ma_hop_dong = ac.ma_hop_dong
JOIN QuangCao a ON ac.ma_quang_cao = a.ma_quang_cao
WHERE e.tieu_de_tap LIKE 'EP99%%'
ORDER BY s.giay_bat_dau ASC
""",
    },
    "Q3": {
        "id": "Q3",
        "owner": "Quân",
        "title": "Số lượng Subscriber mới theo từng Channel trong tháng",
        "concepts": "LEFT JOIN (lọc tháng ở ON), COUNT, GROUP BY",
        "sql": """
SELECT c.ma_kenh AS channel_id, c.tieu_de_kenh AS channel_title, c.the_loai AS category,
       MAX(CONCAT(%s, '-', LPAD(%s, 2, '0'))) AS report_month,
       COUNT(s.ma_theo_doi) AS new_subscribers_count
FROM KenhPodcast c
LEFT JOIN TheoDoi s
    ON c.ma_kenh = s.ma_kenh
   AND YEAR(s.ngay_theo_doi) = %s
   AND MONTH(s.ngay_theo_doi) = %s
GROUP BY c.ma_kenh, c.tieu_de_kenh, c.the_loai
ORDER BY new_subscribers_count DESC, c.ma_kenh ASC
""",
    },
    "Q4": {
        "id": "Q4",
        "owner": "Quân",
        "title": "Các Channel có Rating trung bình dưới 3",
        "concepts": "Multi-table JOIN, AVG, GROUP BY, HAVING",
        "sql": """
SELECT c.ma_kenh AS channel_id, c.tieu_de_kenh AS channel_title, cr.ten_hien_thi AS creator_name,
       COUNT(r.ma_danh_gia) AS total_ratings,
       ROUND(AVG(r.so_sao), 2) AS avg_rating
FROM KenhPodcast c
JOIN NhaSangTao cr ON c.ma_creator = cr.ma_creator
JOIN TapPodcast e ON c.ma_kenh = e.ma_kenh
JOIN DanhGia r ON e.ma_tap = r.ma_tap
GROUP BY c.ma_kenh, c.tieu_de_kenh, cr.ten_hien_thi
HAVING AVG(r.so_sao) < 3.0
ORDER BY avg_rating ASC
""",
    },
    "Q5": {
        "id": "Q5",
        "owner": "Quân",
        "title": "Danh sách Episode và số lượt nghe (kể cả 0 lượt nghe)",
        "concepts": "LEFT JOIN, COUNT(column), GROUP BY",
        "sql": """
SELECT e.ma_tap AS episode_id, c.tieu_de_kenh AS channel_title, e.tieu_de_tap AS episode_title,
       e.thoi_luong_giay AS duration_seconds, SEC_TO_TIME(e.thoi_luong_giay) AS duration_formatted,
       CASE e.trang_thai WHEN 'da_phat_hanh' THEN 'published' WHEN 'luu_tru' THEN 'archived' ELSE 'draft' END AS status,
       COUNT(lh.ma_lich_su) AS listen_count
FROM TapPodcast e
JOIN KenhPodcast c ON e.ma_kenh = c.ma_kenh
LEFT JOIN LichSuNghe lh ON e.ma_tap = lh.ma_tap
GROUP BY e.ma_tap, c.tieu_de_kenh, e.tieu_de_tap, e.thoi_luong_giay, e.trang_thai
ORDER BY listen_count DESC, e.ma_tap ASC
""",
    },
    "Q6": {
        "id": "Q6",
        "owner": "Quân",
        "title": "Episodes có lượt nghe cao hơn trung bình các tập khác cùng Channel",
        "concepts": "Correlated Subquery",
        "sql": """
SELECT t1.ma_tap AS episode_id, t1.ma_kenh AS channel_id, k.tieu_de_kenh AS channel_title,
       t1.tieu_de_tap AS episode_title,
       (SELECT COUNT(*) FROM LichSuNghe ls1 WHERE ls1.ma_tap = t1.ma_tap) AS listen_count,
       ROUND((
           SELECT COALESCE(AVG(sub.luot_nghe), 0)
           FROM (
               SELECT t2.ma_tap, COUNT(ls2.ma_lich_su) AS luot_nghe
               FROM TapPodcast t2
               LEFT JOIN LichSuNghe ls2 ON t2.ma_tap = ls2.ma_tap
               WHERE t2.ma_kenh = t1.ma_kenh AND t2.ma_tap <> t1.ma_tap
               GROUP BY t2.ma_tap
           ) AS sub
       ), 2) AS avg_other_episodes_listens
FROM TapPodcast t1
JOIN KenhPodcast k ON t1.ma_kenh = k.ma_kenh
WHERE (SELECT COUNT(*) FROM LichSuNghe ls1 WHERE ls1.ma_tap = t1.ma_tap) > (
    SELECT COALESCE(AVG(sub.luot_nghe), 0)
    FROM (
        SELECT t2.ma_tap, COUNT(ls2.ma_lich_su) AS luot_nghe
        FROM TapPodcast t2
        LEFT JOIN LichSuNghe ls2 ON t2.ma_tap = ls2.ma_tap
        WHERE t2.ma_kenh = t1.ma_kenh AND t2.ma_tap <> t1.ma_tap
        GROUP BY t2.ma_tap
    ) AS sub
)
ORDER BY t1.ma_kenh ASC, listen_count DESC
""",
    },
    "Q7": {
        "id": "Q7",
        "owner": "Mạnh",
        "title": "Users có tài khoản > 6 tháng nhưng chưa từng Subscribe",
        "concepts": "NOT IN Subquery, TIMESTAMPDIFF, DATE_SUB",
        "sql": """
SELECT u.ma_nguoi_dung AS user_id, u.ten_dang_nhap AS username, u.ho_ten AS full_name,
       u.email, u.ngay_tao AS created_at,
       TIMESTAMPDIFF(DAY, u.ngay_tao, NOW()) AS days_since_registered
FROM NguoiDung u
WHERE u.ngay_tao < DATE_SUB(NOW(), INTERVAL 6 MONTH)
  AND u.ma_nguoi_dung NOT IN (
      SELECT DISTINCT s.ma_nguoi_dung FROM TheoDoi s WHERE s.ma_nguoi_dung IS NOT NULL
  )
ORDER BY u.ngay_tao ASC
""",
    },
    "Q8": {
        "id": "Q8",
        "owner": "Quang",
        "title": "Doanh thu quảng cáo tích lũy theo Creator qua từng tháng",
        "concepts": "SUM, Window Function SUM() OVER (PARTITION BY ... ORDER BY ...)",
        "sql": """
WITH MonthlyCreatorRevenue AS (
    SELECT cr.ma_creator AS creator_id, cr.ten_hien_thi AS creator_name,
           DATE_FORMAT(ar.ngay_ghi_nhan, '%Y-%m') AS revenue_month,
           SUM(ar.luot_hien_thi) AS monthly_impressions,
           SUM(ar.so_tien) AS monthly_revenue
    FROM DoanhThuQC ar
    JOIN HopDongQC ac ON ar.ma_hop_dong = ac.ma_hop_dong
    JOIN NhaSangTao cr ON ac.ma_creator = cr.ma_creator
    GROUP BY cr.ma_creator, cr.ten_hien_thi, DATE_FORMAT(ar.ngay_ghi_nhan, '%Y-%m')
)
SELECT creator_id, creator_name, revenue_month,
       monthly_impressions, monthly_revenue,
       SUM(monthly_revenue) OVER (
           PARTITION BY creator_id
           ORDER BY revenue_month ASC
           ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
       ) AS cumulative_revenue
FROM MonthlyCreatorRevenue
ORDER BY creator_id ASC, revenue_month ASC
""",
    },
}


@analytics_bp.get("/reports/overview")
def reports_overview():
    """Executive summary KPIs, top podcasts, and cumulative revenue."""
    kpis = db.fetch_one(
        """
        SELECT
            (SELECT COUNT(*) FROM NguoiDung) AS total_users,
            (SELECT COUNT(*) FROM NhaSangTao) AS total_creators,
            (SELECT COUNT(*) FROM KenhPodcast) AS total_channels,
            (SELECT COUNT(*) FROM TapPodcast) AS total_episodes,
            (SELECT COUNT(*) FROM LichSuNghe) AS total_listens,
            (SELECT COUNT(*) FROM HopDongQC WHERE trang_thai = 'hieu_luc') AS active_contracts,
            (SELECT COALESCE(SUM(so_tien), 0) FROM DoanhThuQC) AS total_ad_revenue,
            (SELECT COALESCE(SUM(so_tien_ung_ho), 0) FROM UngHo) AS total_donations
        """
    )

    top_podcasts = db.fetch_all(
        """
        SELECT ch.ma_kenh AS channel_id, ch.tieu_de_kenh AS channel_title, ch.the_loai AS category,
               cr.ten_hien_thi AS creator_name,
               COUNT(DISTINCT lh.ma_lich_su) AS total_listens,
               COUNT(DISTINCT s.ma_theo_doi) AS subscriber_count,
               COALESCE(ROUND(AVG(r.so_sao), 2), 0) AS avg_rating
        FROM KenhPodcast ch
        JOIN NhaSangTao cr ON ch.ma_creator = cr.ma_creator
        LEFT JOIN TapPodcast e ON ch.ma_kenh = e.ma_kenh
        LEFT JOIN LichSuNghe lh ON e.ma_tap = lh.ma_tap
        LEFT JOIN TheoDoi s ON ch.ma_kenh = s.ma_kenh
        LEFT JOIN DanhGia r ON e.ma_tap = r.ma_tap
        GROUP BY ch.ma_kenh, ch.tieu_de_kenh, ch.the_loai, cr.ten_hien_thi
        ORDER BY total_listens DESC, subscriber_count DESC
        """
    )

    cumulative_revenue = db.fetch_all(_QUERY_SPECS["Q8"]["sql"])

    return success(
        {
            "kpis": kpis,
            "top_podcasts": top_podcasts,
            "cumulative_revenue": cumulative_revenue,
        }
    )


@analytics_bp.get("/reports/cumulative-revenue")
def cumulative_revenue_report():
    """Execute Q8 Window Function report."""
    rows = db.fetch_all(_QUERY_SPECS["Q8"]["sql"])
    return success(rows)


@analytics_bp.get("/reports/queries")
def list_queries():
    """List metadata for all 8 required project SQL queries."""
    items = [
        {
            "id": spec["id"],
            "owner": spec["owner"],
            "title": spec["title"],
            "concepts": spec["concepts"],
            "sql": spec["sql"].strip(),
        }
        for spec in _QUERY_SPECS.values()
    ]
    return success(items)


@analytics_bp.get("/reports/queries/<string:query_id>")
def run_named_query(query_id: str):
    """Execute one of the 8 allow-listed project queries (Q1..Q8)."""
    qid = query_id.upper()
    spec = _QUERY_SPECS.get(qid)
    if not spec:
        raise AppError(f"Không tồn tại câu truy vấn '{query_id}'. Chỉ hỗ trợ Q1..Q8.", status_code=404)

    params: tuple = ()
    if qid == "Q1":
        channel_id = request.args.get("channel_id", default="KP0001", type=str).strip()
        params = (channel_id,)
    elif qid == "Q3":
        from datetime import date

        today = date.today()
        year = request.args.get("year", default=today.year, type=int)
        month = request.args.get("month", default=today.month, type=int)
        params = (year, month, year, month)

    rows = db.fetch_all(spec["sql"], params)
    return success(
        {
            "id": spec["id"],
            "owner": spec["owner"],
            "title": spec["title"],
            "concepts": spec["concepts"],
            "sql": spec["sql"].strip(),
            "row_count": len(rows),
            "rows": rows,
        }
    )
