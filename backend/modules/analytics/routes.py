"""Module 03: Advertisement, Donations & Business Analytics RESTful API Blueprint."""

from flask import Blueprint, request

from common.auth import get_current_user, login_required, roles_required
from common.errors import AppError
from common.response import success
from config import db

analytics_bp = Blueprint("analytics", __name__, url_prefix="/api/analytics")


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
# Advertisements CRUD
# -------------------------------------------------------------------

@analytics_bp.get("/ads")
def list_ads():
    """List advertisements."""
    status = request.args.get("status", "").strip()
    if status:
        rows = db.fetch_all("SELECT * FROM Advertisements WHERE status = %s ORDER BY ad_id DESC", (status,))
    else:
        rows = db.fetch_all("SELECT * FROM Advertisements ORDER BY ad_id DESC")
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
    status = str(data.get("status", "active")).strip().lower()
    if status not in ("active", "paused", "archived"):
        raise AppError("Trạng thái quảng cáo không hợp lệ.", status_code=400)

    _, ad_id = db.execute(
        """
        INSERT INTO Advertisements (advertiser_name, title, description, ad_audio_url, target_url, duration_seconds, status)
        VALUES (%s, %s, %s, %s, %s, %s, %s)
        """,
        (
            str(data["advertiser_name"]).strip(),
            str(data["title"]).strip(),
            str(data.get("description") or "").strip() or None,
            data.get("ad_audio_url"),
            data.get("target_url"),
            duration,
            status,
        ),
    )
    row = db.fetch_one("SELECT * FROM Advertisements WHERE ad_id = %s", (ad_id,))
    return success(row, message="Tạo quảng cáo thành công.", status=201)


@analytics_bp.put("/ads/<int:ad_id>")
@roles_required("creator", "admin")
def update_ad(ad_id: int):
    """Update an advertisement campaign."""
    existing = db.fetch_one("SELECT * FROM Advertisements WHERE ad_id = %s", (ad_id,))
    if not existing:
        raise AppError("Không tìm thấy quảng cáo.", status_code=404)
    data = _json_body()
    db.execute(
        """
        UPDATE Advertisements
        SET advertiser_name = %s, title = %s, description = %s, target_url = %s,
            duration_seconds = %s, status = %s
        WHERE ad_id = %s
        """,
        (
            str(data.get("advertiser_name") or existing["advertiser_name"]).strip(),
            str(data.get("title") or existing["title"]).strip(),
            data.get("description", existing["description"]),
            data.get("target_url", existing["target_url"]),
            int(data.get("duration_seconds", existing["duration_seconds"])),
            str(data.get("status", existing["status"])).strip().lower(),
            ad_id,
        ),
    )
    row = db.fetch_one("SELECT * FROM Advertisements WHERE ad_id = %s", (ad_id,))
    return success(row, message="Cập nhật quảng cáo thành công.")


# -------------------------------------------------------------------
# AdContracts CRUD
# -------------------------------------------------------------------

@analytics_bp.get("/contracts")
def list_contracts():
    """List ad contracts joined with ad and creator info."""
    creator_id = request.args.get("creator_id", type=int)
    where_sql = "WHERE ac.creator_id = %s" if creator_id else ""
    params = (creator_id,) if creator_id else ()
    rows = db.fetch_all(
        f"""
        SELECT ac.*, a.advertiser_name, a.title AS ad_title, a.duration_seconds AS ad_duration_seconds,
               cr.display_name AS creator_name,
               COUNT(DISTINCT sl.slot_id) AS assigned_slots_count,
               COALESCE(SUM(ar.amount), 0) AS realized_revenue
        FROM AdContracts ac
        INNER JOIN Advertisements a ON ac.ad_id = a.ad_id
        INNER JOIN Creators cr ON ac.creator_id = cr.creator_id
        LEFT JOIN AdSlots sl ON ac.contract_id = sl.contract_id
        LEFT JOIN AdRevenue ar ON ac.contract_id = ar.contract_id
        {where_sql}
        GROUP BY ac.contract_id, a.advertiser_name, a.title, a.duration_seconds, cr.display_name
        ORDER BY ac.contract_id DESC
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

    creator_id = int(data.get("creator_id") or user.get("creator_id") or 0)
    if not creator_id:
        raise AppError("Thiếu creator_id cho hợp đồng.", status_code=400)
    if user["role"] != "admin" and creator_id != user.get("creator_id"):
        raise AppError("Bạn chỉ có thể tạo hợp đồng cho Creator của chính mình.", status_code=403)

    _, contract_id = db.execute(
        """
        INSERT INTO AdContracts (ad_id, creator_id, contract_code, contract_value, cpm_rate, start_date, end_date, status)
        VALUES (%s, %s, %s, %s, %s, %s, %s, %s)
        """,
        (
            int(data["ad_id"]),
            creator_id,
            str(data["contract_code"]).strip(),
            float(data["contract_value"]),
            float(data.get("cpm_rate", 0)),
            str(data["start_date"]).strip(),
            str(data["end_date"]).strip(),
            str(data.get("status", "active")).strip().lower(),
        ),
    )
    row = db.fetch_one("SELECT * FROM AdContracts WHERE contract_id = %s", (contract_id,))
    return success(row, message="Tạo hợp đồng quảng cáo thành công.", status=201)


# -------------------------------------------------------------------
# AdSlots CRUD (Protected by MySQL Trigger TRG_AdSlots_Limit_Contracts_BI)
# -------------------------------------------------------------------

@analytics_bp.get("/slots")
def list_slots():
    """List ad slot placements across episodes."""
    episode_id = request.args.get("episode_id", type=int)
    where_sql = "WHERE s.episode_id = %s" if episode_id else ""
    params = (episode_id,) if episode_id else ()
    rows = db.fetch_all(
        f"""
        SELECT s.*, e.title AS episode_title, e.duration_seconds AS episode_duration_seconds,
               ch.channel_id, ch.title AS channel_title,
               ac.contract_code, ac.creator_id,
               a.advertiser_name, a.title AS ad_title
        FROM AdSlots s
        INNER JOIN Episodes e ON s.episode_id = e.episode_id
        INNER JOIN PodcastChannels ch ON e.channel_id = ch.channel_id
        INNER JOIN AdContracts ac ON s.contract_id = ac.contract_id
        INNER JOIN Advertisements a ON ac.ad_id = a.ad_id
        {where_sql}
        ORDER BY s.episode_id ASC, s.start_offset_seconds ASC
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

    contract_id = int(data["contract_id"])
    episode_id = int(data["episode_id"])
    slot_position = str(data.get("slot_position", "mid-roll")).strip().lower()
    if slot_position not in ("pre-roll", "mid-roll", "post-roll"):
        raise AppError("Vị trí quảng cáo phải là pre-roll, mid-roll hoặc post-roll.", status_code=400)

    offset = int(data.get("start_offset_seconds", 0))
    status = str(data.get("status", "active")).strip().lower()

    ep_info = db.fetch_one(
        """
        SELECT e.duration_seconds, ch.creator_id
        FROM Episodes e
        INNER JOIN PodcastChannels ch ON e.channel_id = ch.channel_id
        WHERE e.episode_id = %s
        """,
        (episode_id,),
    )
    if not ep_info:
        raise AppError("Episode không tồn tại.", status_code=404)

    if user["role"] != "admin" and ep_info["creator_id"] != user.get("creator_id"):
        raise AppError("Bạn không có quyền gắn quảng cáo vào Episode của Creator khác.", status_code=403)

    contract_info = db.fetch_one(
        "SELECT contract_id, creator_id FROM AdContracts WHERE contract_id = %s",
        (contract_id,),
    )
    if not contract_info:
        raise AppError("Hợp đồng quảng cáo không tồn tại.", status_code=404)

    # Rule 1: Hợp đồng quảng cáo phải thuộc cùng Creator với Episode
    if ep_info["creator_id"] != contract_info["creator_id"]:
        raise AppError("Hợp đồng quảng cáo chỉ được gắn vào Episode thuộc cùng Creator.", status_code=400)

    # Rule 2: Thời điểm chèn quảng cáo không âm và không vượt quá thời lượng Episode
    if offset < 0 or offset > ep_info["duration_seconds"]:
        raise AppError("Vị trí quảng cáo (start_offset_seconds) vượt quá thời lượng Episode.", status_code=400)

    # Rule 3: Episode dưới 20 phút (< 1200s) chỉ được gắn tối đa 3 hợp đồng khác nhau
    if ep_info["duration_seconds"] < 1200:
        slot_stats = db.fetch_one(
            """
            SELECT COUNT(DISTINCT contract_id) AS distinct_contracts,
                   COALESCE(MAX(CASE WHEN contract_id = %s THEN 1 ELSE 0 END), 0) AS already_attached
            FROM AdSlots
            WHERE episode_id = %s
            """,
            (contract_id, episode_id),
        )
        if slot_stats and slot_stats["already_attached"] == 0 and slot_stats["distinct_contracts"] >= 3:
            raise AppError(
                "Episode dưới 20 phút (< 1200s) chỉ được gắn tối đa 3 hợp đồng quảng cáo.",
                status_code=400,
            )

    _, slot_id = db.execute(
        """
        INSERT INTO AdSlots (contract_id, episode_id, slot_position, start_offset_seconds, status)
        VALUES (%s, %s, %s, %s, %s)
        """,
        (contract_id, episode_id, slot_position, offset, status),
    )
    row = db.fetch_one("SELECT * FROM AdSlots WHERE slot_id = %s", (slot_id,))
    return success(row, message="Đã gắn quảng cáo vào Episode thành công.", status=201)


@analytics_bp.delete("/slots/<int:slot_id>")
@roles_required("creator", "admin")
def delete_slot(slot_id: int):
    """Remove an ad slot placement."""
    user = get_current_user()
    existing = db.fetch_one(
        """
        SELECT s.slot_id, ch.creator_id
        FROM AdSlots s
        INNER JOIN Episodes e ON s.episode_id = e.episode_id
        INNER JOIN PodcastChannels ch ON e.channel_id = ch.channel_id
        WHERE s.slot_id = %s
        """,
        (slot_id,),
    )
    if not existing:
        raise AppError("Không tìm thấy AdSlot.", status_code=404)
    if user["role"] != "admin" and existing["creator_id"] != user.get("creator_id"):
        raise AppError("Bạn không có quyền xóa AdSlot này.", status_code=403)

    db.execute("DELETE FROM AdSlots WHERE slot_id = %s", (slot_id,))
    return success({"deleted_slot_id": slot_id}, message="Đã gỡ AdSlot khỏi Episode.")


# -------------------------------------------------------------------
# AdRevenue & Donations
# -------------------------------------------------------------------

@analytics_bp.get("/revenue")
def list_revenue():
    """List ad revenue entries joined with contracts and creators."""
    rows = db.fetch_all(
        """
        SELECT ar.*, ac.contract_code, cr.creator_id, cr.display_name AS creator_name,
               a.advertiser_name, a.title AS ad_title
        FROM AdRevenue ar
        INNER JOIN AdContracts ac ON ar.contract_id = ac.contract_id
        INNER JOIN Creators cr ON ac.creator_id = cr.creator_id
        INNER JOIN Advertisements a ON ac.ad_id = a.ad_id
        ORDER BY ar.revenue_date DESC, ar.revenue_id DESC
        """
    )
    return success(rows)


@analytics_bp.post("/revenue")
@roles_required("creator", "admin")
def create_revenue():
    """Record a new ad revenue entry."""
    data = _json_body()
    _require_fields(data, "contract_id", "revenue_date", "amount")
    _, rev_id = db.execute(
        """
        INSERT INTO AdRevenue (contract_id, slot_id, revenue_date, impressions, amount, notes)
        VALUES (%s, %s, %s, %s, %s, %s)
        """,
        (
            int(data["contract_id"]),
            int(data["slot_id"]) if data.get("slot_id") else None,
            str(data["revenue_date"]).strip(),
            int(data.get("impressions", 0)),
            float(data["amount"]),
            str(data.get("notes") or "").strip() or None,
        ),
    )
    row = db.fetch_one("SELECT * FROM AdRevenue WHERE revenue_id = %s", (rev_id,))
    return success(row, message="Đã ghi nhận doanh thu quảng cáo.", status=201)


@analytics_bp.get("/donations")
def list_donations():
    """List donation history."""
    rows = db.fetch_all(
        """
        SELECT d.*, u.username AS donor_username, u.full_name AS donor_name,
               cr.display_name AS creator_name, e.title AS episode_title
        FROM Donations d
        INNER JOIN Users u ON d.donor_user_id = u.user_id
        INNER JOIN Creators cr ON d.creator_id = cr.creator_id
        LEFT JOIN Episodes e ON d.episode_id = e.episode_id
        ORDER BY d.donated_at DESC, d.donation_id DESC
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

    _, donation_id = db.execute(
        """
        INSERT INTO Donations (donor_user_id, creator_id, episode_id, amount, message)
        VALUES (%s, %s, %s, %s, %s)
        """,
        (
            user["user_id"],
            int(data["creator_id"]),
            int(data["episode_id"]) if data.get("episode_id") else None,
            amount,
            str(data.get("message") or "").strip() or None,
        ),
    )
    row = db.fetch_one(
        """
        SELECT d.*, u.username AS donor_username, u.full_name AS donor_name,
               cr.display_name AS creator_name, e.title AS episode_title
        FROM Donations d
        INNER JOIN Users u ON d.donor_user_id = u.user_id
        INNER JOIN Creators cr ON d.creator_id = cr.creator_id
        LEFT JOIN Episodes e ON d.episode_id = e.episode_id
        WHERE d.donation_id = %s
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
        "concepts": "INNER JOIN, WHERE, BETWEEN, SEC_TO_TIME",
        "sql": """
SELECT e.episode_id, c.title AS channel_name, e.title AS episode_title,
       e.duration_seconds, SEC_TO_TIME(e.duration_seconds) AS duration_formatted,
       e.published_at, e.status
FROM Episodes e
INNER JOIN PodcastChannels c ON e.channel_id = c.channel_id
WHERE e.channel_id = %s
  AND e.status = 'published'
  AND e.duration_seconds BETWEEN 900 AND 1800
ORDER BY e.duration_seconds ASC
""",
    },
    "Q2": {
        "id": "Q2",
        "owner": "Quang",
        "title": "Các quảng cáo xuất hiện trong EP99",
        "concepts": "Multi-table INNER JOIN (4 bảng), LIKE",
        "sql": """
SELECT e.episode_id, e.title AS episode_title, s.slot_position,
       s.start_offset_seconds, SEC_TO_TIME(s.start_offset_seconds) AS offset_formatted,
       ac.contract_code, a.ad_id, a.advertiser_name, a.title AS ad_title,
       a.duration_seconds AS ad_duration_seconds
FROM Episodes e
INNER JOIN AdSlots s ON e.episode_id = s.episode_id
INNER JOIN AdContracts ac ON s.contract_id = ac.contract_id
INNER JOIN Advertisements a ON ac.ad_id = a.ad_id
WHERE e.title LIKE 'EP99%%'
ORDER BY s.start_offset_seconds ASC
""",
    },
    "Q3": {
        "id": "Q3",
        "owner": "Quân",
        "title": "Số lượng Subscriber mới theo từng Channel trong tháng",
        "concepts": "LEFT JOIN (lọc tháng ở ON), COUNT, GROUP BY",
        "sql": """
SELECT c.channel_id, c.title AS channel_title, c.category,
       MAX(CONCAT(%s, '-', LPAD(%s, 2, '0'))) AS report_month,
       COUNT(s.subscription_id) AS new_subscribers_count
FROM PodcastChannels c
LEFT JOIN Subscriptions s
    ON c.channel_id = s.channel_id
   AND YEAR(s.subscribed_at) = %s
   AND MONTH(s.subscribed_at) = %s
GROUP BY c.channel_id, c.title, c.category
ORDER BY new_subscribers_count DESC, c.channel_id ASC
""",
    },
    "Q4": {
        "id": "Q4",
        "owner": "Quân",
        "title": "Các Channel có Rating trung bình dưới 3",
        "concepts": "Multi-table INNER JOIN, AVG, GROUP BY, HAVING",
        "sql": """
SELECT c.channel_id, c.title AS channel_title, cr.display_name AS creator_name,
       COUNT(r.rating_id) AS total_ratings,
       ROUND(AVG(r.score), 2) AS avg_rating
FROM PodcastChannels c
INNER JOIN Creators cr ON c.creator_id = cr.creator_id
INNER JOIN Episodes e ON c.channel_id = e.channel_id
INNER JOIN Ratings r ON e.episode_id = r.episode_id
GROUP BY c.channel_id, c.title, cr.display_name
HAVING AVG(r.score) < 3.0
ORDER BY avg_rating ASC
""",
    },
    "Q5": {
        "id": "Q5",
        "owner": "Quân",
        "title": "Danh sách Episode và số lượt nghe (kể cả 0 lượt nghe)",
        "concepts": "LEFT JOIN, COUNT(column), GROUP BY",
        "sql": """
SELECT e.episode_id, c.title AS channel_title, e.title AS episode_title,
       e.duration_seconds, SEC_TO_TIME(e.duration_seconds) AS duration_formatted,
       e.status, COUNT(lh.history_id) AS listen_count
FROM Episodes e
INNER JOIN PodcastChannels c ON e.channel_id = c.channel_id
LEFT JOIN ListeningHistory lh ON e.episode_id = lh.episode_id
GROUP BY e.episode_id, c.title, e.title, e.duration_seconds, e.status
ORDER BY listen_count DESC, e.episode_id ASC
""",
    },
    "Q6": {
        "id": "Q6",
        "owner": "Quân",
        "title": "Episodes có lượt nghe cao hơn trung bình các tập khác cùng Channel",
        "concepts": "CTE (WITH), Window Function SUM/COUNT OVER (PARTITION BY)",
        "sql": """
WITH EpisodeListens AS (
    SELECT e.episode_id, e.channel_id, c.title AS channel_title,
           e.title AS episode_title, COUNT(lh.history_id) AS listen_count
    FROM Episodes e
    INNER JOIN PodcastChannels c ON e.channel_id = c.channel_id
    LEFT JOIN ListeningHistory lh ON e.episode_id = lh.episode_id
    GROUP BY e.episode_id, e.channel_id, c.title, e.title
),
ChannelPeerAverage AS (
    SELECT episode_id, channel_id, channel_title, episode_title, listen_count,
           ROUND(
               (SUM(listen_count) OVER (PARTITION BY channel_id) - listen_count)
               / NULLIF(COUNT(*) OVER (PARTITION BY channel_id) - 1, 0),
               2
           ) AS avg_other_episodes_listens
    FROM EpisodeListens
)
SELECT episode_id, channel_id, channel_title, episode_title,
       listen_count, avg_other_episodes_listens
FROM ChannelPeerAverage
WHERE avg_other_episodes_listens IS NOT NULL
  AND listen_count > avg_other_episodes_listens
ORDER BY channel_id ASC, listen_count DESC
""",
    },
    "Q7": {
        "id": "Q7",
        "owner": "Mạnh",
        "title": "Users có tài khoản > 6 tháng nhưng chưa từng Subscribe",
        "concepts": "NOT EXISTS Subquery, TIMESTAMPDIFF, DATE_SUB",
        "sql": """
SELECT u.user_id, u.username, u.full_name, u.email, u.created_at,
       TIMESTAMPDIFF(DAY, u.created_at, NOW()) AS days_since_registered
FROM Users u
WHERE u.created_at < DATE_SUB(NOW(), INTERVAL 6 MONTH)
  AND NOT EXISTS (
      SELECT 1 FROM Subscriptions s WHERE s.user_id = u.user_id
  )
ORDER BY u.created_at ASC
""",
    },
    "Q8": {
        "id": "Q8",
        "owner": "Quang",
        "title": "Doanh thu quảng cáo tích lũy theo Creator qua từng tháng",
        "concepts": "CTE, SUM, Window Function SUM() OVER (PARTITION BY ... ORDER BY ...)",
        "sql": """
WITH MonthlyCreatorRevenue AS (
    SELECT cr.creator_id, cr.display_name AS creator_name,
           DATE_FORMAT(ar.revenue_date, '%Y-%m') AS revenue_month,
           SUM(ar.impressions) AS monthly_impressions,
           SUM(ar.amount) AS monthly_revenue
    FROM AdRevenue ar
    INNER JOIN AdContracts ac ON ar.contract_id = ac.contract_id
    INNER JOIN Creators cr ON ac.creator_id = cr.creator_id
    GROUP BY cr.creator_id, cr.display_name, DATE_FORMAT(ar.revenue_date, '%Y-%m')
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
            (SELECT COUNT(*) FROM Users) AS total_users,
            (SELECT COUNT(*) FROM Creators) AS total_creators,
            (SELECT COUNT(*) FROM PodcastChannels) AS total_channels,
            (SELECT COUNT(*) FROM Episodes) AS total_episodes,
            (SELECT COUNT(*) FROM ListeningHistory) AS total_listens,
            (SELECT COUNT(*) FROM AdContracts WHERE status = 'active') AS active_contracts,
            (SELECT COALESCE(SUM(amount), 0) FROM AdRevenue) AS total_ad_revenue,
            (SELECT COALESCE(SUM(amount), 0) FROM Donations) AS total_donations
        """
    )

    top_podcasts = db.fetch_all(
        """
        SELECT ch.channel_id, ch.title AS channel_title, ch.category,
               cr.display_name AS creator_name,
               COUNT(DISTINCT lh.history_id) AS total_listens,
               COUNT(DISTINCT s.subscription_id) AS subscriber_count,
               COALESCE(ROUND(AVG(r.score), 2), 0) AS avg_rating
        FROM PodcastChannels ch
        INNER JOIN Creators cr ON ch.creator_id = cr.creator_id
        LEFT JOIN Episodes e ON ch.channel_id = e.channel_id
        LEFT JOIN ListeningHistory lh ON e.episode_id = lh.episode_id
        LEFT JOIN Subscriptions s ON ch.channel_id = s.channel_id
        LEFT JOIN Ratings r ON e.episode_id = r.episode_id
        GROUP BY ch.channel_id, ch.title, ch.category, cr.display_name
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
        channel_id = request.args.get("channel_id", default=1, type=int)
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
