# API Documentation — Podify RESTful API

Tài liệu đặc tả các RESTful API endpoints của hệ thống **Podify** (Backend Python Flask), chia theo 3 Blueprint tương ứng 3 phân hệ.

- **Base URL:** `http://127.0.0.1:5000`
- **Format phản hồi chuẩn:**
  - Thành công: `{ "ok": true, "message": "...", "data": ... }`
  - Lỗi: `{ "ok": false, "error": "Thông báo lỗi", "code": "ERROR_CODE" }`
- **Xác thực:** Header `Authorization: Bearer <token>` (nhận từ `/api/content/auth/login` hoặc `/register`).

---

## 0. Health Check
| Method | Endpoint | Auth | Mô tả |
| :--- | :--- | :--- | :--- |
| `GET` | `/api/health` | Public | Kiểm tra service backend; thêm `?db=1` để kiểm tra kết nối MySQL và số lượng bảng trong `podify_db`. |

---

## 1. Module 01: Content Management (`/api/content`)

| Method | Endpoint | Auth / Role | Mô tả |
| :--- | :--- | :--- | :--- |
| `POST` | `/api/content/auth/register` | Public | Đăng ký tài khoản (`username`, `email`, `password`, `full_name`, `role`: `'user'` \| `'creator'`). Trả về `token` + `user`. |
| `POST` | `/api/content/auth/login` | Public | Đăng nhập bằng `identifier` (`username` hoặc `email`) và `password`. |
| `GET` | `/api/content/auth/me` | Login | Lấy thông tin người dùng hiện tại + hồ sơ `Creators` (nếu có). |
| `GET` | `/api/content/users/demo` | Public | Lấy danh sách tài khoản demo phục vụ chuyển nhanh tài khoản trên UI. |
| `GET` | `/api/content/creators` | Public | Danh sách Creator kèm số kênh, số tập, tổng subscriber. |
| `PUT` | `/api/content/creators/profile` | Creator/Admin | Cập nhật hồ sơ Creator (`display_name`, `bio`). |
| `GET` | `/api/content/channels` | Public / Optional | Tìm kiếm và lọc kênh (`?q=`, `?category=`, `?creator_id=`). |
| `GET` | `/api/content/channels/<channel_id>` | Public / Optional | Chi tiết kênh + danh sách Episode thuộc kênh. |
| `POST` | `/api/content/channels` | Creator/Admin | Tạo kênh Podcast mới (`title`, `category`, `description`). |
| `PUT` | `/api/content/channels/<channel_id>` | Owner/Admin | Cập nhật thông tin kênh. |
| `DELETE` | `/api/content/channels/<channel_id>` | Owner/Admin | Xóa kênh (Cascade xóa Episodes, Subscriptions...). |
| `GET` | `/api/content/episodes` | Public | Tìm/lọc Episode (`?q=`, `?channel_id=`, `?category=`, `?status=`, `?min_duration=`, `?max_duration=`). |
| `GET` | `/api/content/episodes/<episode_id>` | Public | Chi tiết Episode kèm danh sách `ad_slots`. |
| `POST` | `/api/content/episodes` | Creator/Admin | Tạo Episode mới (`channel_id`, `title`, `audio_url`, `duration_seconds`, `status`). |
| `PUT` | `/api/content/episodes/<episode_id>` | Owner/Admin | Cập nhật Episode (Trigger sẽ chặn nếu giảm `duration_seconds < 1200` khi đã có > 3 hợp đồng). |
| `DELETE` | `/api/content/episodes/<episode_id>` | Owner/Admin | Xóa Episode. |

---

## 2. Module 02: Listening & User Interaction (`/api/listening`)

| Method | Endpoint | Auth / Role | Mô tả |
| :--- | :--- | :--- | :--- |
| `GET` | `/api/listening/home` | Optional | Trả về `channels`, `episodes`, `history`, `continue_episode` cho trang Home. |
| `GET` | `/api/listening/subscriptions` | Login | Danh sách kênh người dùng hiện tại đang theo dõi. |
| `POST` | `/api/listening/subscriptions` | Login | Đăng ký kênh (`channel_id`). Trả về `409 Conflict` nếu trùng lặp (`UQ_Subscriptions_User_Channel`). |
| `DELETE` | `/api/listening/subscriptions/<channel_id>` | Login | Hủy theo dõi kênh. |
| `GET` | `/api/listening/history` | Login | Lịch sử các phiên nghe của người dùng hiện tại. |
| `POST` | `/api/listening/progress` | Login | Tạo phiên nghe mới (`new_session: true`) hoặc cập nhật tiến trình `position_seconds`, `is_completed` trên `ListeningHistory`. |
| `GET` | `/api/listening/ratings` | Optional | Danh sách Episode kèm điểm trung bình và đánh giá của user hiện tại. |
| `POST` | `/api/listening/ratings` | Login | Tạo hoặc cập nhật đánh giá (`episode_id`, `score` 1–5, `comment`). |
| `DELETE` | `/api/listening/ratings/<episode_id>` | Login | Xóa đánh giá của user hiện tại. |

---

## 3. Module 03: Advertisement & Analytics (`/api/analytics`)

| Method | Endpoint | Auth / Role | Mô tả |
| :--- | :--- | :--- | :--- |
| `GET` | `/api/analytics/ads` | Public | Danh sách chiến dịch quảng cáo (`?status=`). |
| `POST` | `/api/analytics/ads` | Creator/Admin | Tạo chiến dịch quảng cáo (`advertiser_name`, `title`, `duration_seconds`). |
| `PUT` | `/api/analytics/ads/<ad_id>` | Creator/Admin | Cập nhật thông tin quảng cáo. |
| `GET` | `/api/analytics/contracts` | Public | Danh sách hợp đồng (`?creator_id=`) kèm số lượng `AdSlots` và tổng doanh thu thực tế. |
| `POST` | `/api/analytics/contracts` | Creator/Admin | Tạo hợp đồng quảng cáo (`ad_id`, `contract_code`, `contract_value`, `cpm_rate`, `start_date`, `end_date`). |
| `GET` | `/api/analytics/slots` | Public | Danh sách vị trí quảng cáo trong Episode (`?episode_id=`). |
| `POST` | `/api/analytics/slots` | Creator/Admin | Gắn `contract_id` vào `episode_id` tại `slot_position` + `start_offset_seconds`. Nếu vi phạm Trigger (`< 20p` và `>= 3` hợp đồng), trả `400` (`DB_TRIGGER_VIOLATION`). |
| `DELETE` | `/api/analytics/slots/<slot_id>` | Owner/Admin | Gỡ bỏ AdSlot khỏi Episode. |
| `GET` | `/api/analytics/revenue` | Public | Danh sách bản ghi doanh thu `AdRevenue`. |
| `POST` | `/api/analytics/revenue` | Creator/Admin | Ghi nhận doanh thu mới. |
| `GET` | `/api/analytics/donations` | Public | Lịch sử các khoản ủng hộ `Donations`. |
| `POST` | `/api/analytics/donations` | Login | Gửi ủng hộ (`creator_id`, `episode_id` tùy chọn, `amount > 0`, `message`). |
| `GET` | `/api/analytics/reports/overview` | Public | KPIs tổng quan, Top Podcast Channels và báo cáo tích lũy `Q8`. |
| `GET` | `/api/analytics/reports/cumulative-revenue` | Public | Chạy báo cáo Window Function `Q8`. |
| `GET` | `/api/analytics/reports/queries` | Public | Lấy danh mục 8 truy vấn `Q1`–`Q8`. |
| `GET` | `/api/analytics/reports/queries/<Q1..Q8>` | Public | Thực thi truy vấn theo mã (`Q1` hỗ trợ `?channel_id=`, `Q3` hỗ trợ `?year=&month=`). |

---

## 4. Bảng mã lỗi HTTP chuẩn hóa

| HTTP Code | `code` trong JSON | Nguyên nhân |
| :--- | :--- | :--- |
| `400` | `DB_TRIGGER_VIOLATION` | Bị MySQL Trigger chặn bằng `SIGNAL SQLSTATE '45000'`. |
| `400` | `DB_CONSTRAINT_VIOLATION` / `MISSING_FIELDS` | Vi phạm `CHECK`, `NOT NULL`, `FOREIGN KEY` hoặc thiếu dữ liệu đầu vào. |
| `401` | `AUTH_REQUIRED` / `TOKEN_INVALID` / `INVALID_CREDENTIALS` | Chưa đăng nhập, token sai/hết hạn hoặc sai mật khẩu. |
| `403` | `FORBIDDEN` | Không đúng vai trò (`creator`/`admin`) hoặc không phải chủ sở hữu tài nguyên. |
| `404` | `HTTP_404` | Không tìm thấy bản ghi. |
| `409` | `DB_DUPLICATE_ENTRY` | Trùng `username`, `email`, `contract_code`, `Subscriptions(user, channel)`... |
| `503` | `DB_UNAVAILABLE` | Chưa cấu hình `.env` hoặc MySQL Server chưa chạy. |
