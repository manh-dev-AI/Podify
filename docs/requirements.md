# Requirements & Business Rules — Podify

Tài liệu phân tích yêu cầu chức năng, phi chức năng và các quy tắc nghiệp vụ (Business Rules) cho hệ thống **Podify — Podcast & Audio Content Management System**.

---

## 1. Đối tượng sử dụng & Phân quyền (`Users.role`)

| Vai trò (`role`) | Mô tả | Quyền hạn chính |
| :--- | :--- | :--- |
| **Guest** (Chưa đăng nhập) | Khách truy cập web | Xem danh sách kênh, tập Podcast, nghe thử audio, xem báo cáo/analytics tổng quan. |
| **User** (`user`) | Người nghe Podcast | Đăng ký/hủy theo dõi kênh (`Subscriptions`), lưu tiến trình nghe (`ListeningHistory`), chấm điểm 1–5 sao (`Ratings`), gửi ủng hộ tài chính (`Donations`). |
| **Creator** (`creator`) | Nhà sáng tạo nội dung | Toàn bộ quyền của `user` + quản lý hồ sơ `Creators`, tạo/sửa/xóa `PodcastChannels` & `Episodes`, tạo quảng cáo (`Advertisements`), lập hợp đồng (`AdContracts`), gắn vị trí quảng cáo (`AdSlots`), ghi nhận doanh thu (`AdRevenue`). |
| **Admin** (`admin`) | Quản trị hệ thống | Toàn quyền quản trị nội dung và quảng cáo trên toàn nền tảng. |

---

## 2. Yêu cầu chức năng theo 3 phân hệ

### Phân hệ 01 — Content Management (Mạnh)
- Đăng ký tài khoản (`user` hoặc `creator` — tự động khởi tạo bản ghi `Creators` trong cùng transaction).
- Đăng nhập / xác thực bằng mật khẩu băm (`pbkdf2:sha256`) và cấp Token phiên làm việc.
- Quản lý hồ sơ Creator (`display_name`, `bio`, `verified`).
- CRUD `PodcastChannels` và `Episodes` (hỗ trợ trạng thái `draft`, `published`, `archived`).
- Tìm kiếm và lọc kênh/tập theo từ khóa, danh mục (`category`) và khoảng thời lượng (ví dụ 15–30 phút phục vụ `Q1`).

### Phân hệ 02 — Listening & User Interaction (Quân)
- Theo dõi / hủy theo dõi kênh (`Subscriptions`).
- Trình phát Audio HTML5 (`<audio>`) hỗ trợ Play/Pause, tua `-15s`/`+30s`, click thanh tiến trình và tự động đồng bộ vị trí dừng (`last_position_seconds`) lên `ListeningHistory`.
- Hiển thị mục **Continue Listening**, **My Library** (lọc theo tập, kênh đã theo dõi, tập yêu thích), **Listening History**.
- Đánh giá Episode theo thang điểm `1..5` sao kèm bình luận (`Ratings`).

### Phân hệ 03 — Advertisement & Analytics (Quang)
- Quản lý chiến dịch quảng cáo (`Advertisements`) và hợp đồng thương mại (`AdContracts`).
- Gắn hợp đồng quảng cáo vào vị trí cụ thể trong Episode (`AdSlots`: `pre-roll`, `mid-roll`, `post-roll` kèm `start_offset_seconds`).
- Ghi nhận doanh thu quảng cáo theo ngày (`AdRevenue`) và lịch sử ủng hộ (`Donations`).
- Dashboard thống kê: KPI tổng quan, Top Podcast Channels, Doanh thu tích lũy theo Creator qua từng tháng (`Q8`), và trình chạy 8 truy vấn nghiệp vụ (`Q1`–`Q8`).

---

## 3. Quy tắc nghiệp vụ & Ràng buộc toàn vẹn dữ liệu (Business Rules)

1. **Duy nhất tài khoản & hồ sơ Creator:**
   - `Users.username` và `Users.email` là `UNIQUE`.
   - `Creators.user_id` là `UNIQUE` (quan hệ `1 : 0..1` giữa `Users` và `Creators`).
2. **Chống đăng ký trùng & đánh giá trùng:**
   - `Subscriptions`: ràng buộc `UNIQUE(user_id, channel_id)` — một người dùng chỉ đăng ký tối đa 1 lần cho cùng một kênh.
   - `Ratings`: ràng buộc `UNIQUE(user_id, episode_id)` và `CHECK (score BETWEEN 1 AND 5)`.
3. **Tính hợp lệ của giá trị số & thời gian:**
   - `Episodes.duration_seconds > 0` và `Advertisements.duration_seconds > 0`.
   - `ListeningHistory.last_position_seconds >= 0` và `AdSlots.start_offset_seconds >= 0`.
   - `AdContracts`: `contract_value >= 0`, `cpm_rate >= 0`, `end_date >= start_date`.
   - `AdRevenue`: `impressions >= 0`, `amount >= 0`.
   - `Donations.amount > 0`.
4. **Quy tắc Trigger quảng cáo (Tầng CSDL MySQL):**
   - **Giới hạn hợp đồng theo thời lượng:** Mỗi Episode có thời lượng **dưới 20 phút (`duration_seconds < 1200`)** chỉ được phép gắn tối đa **3 hợp đồng quảng cáo (`AdContracts`) khác nhau** thông qua bảng `AdSlots` (chặn cả lúc `INSERT`/`UPDATE` trên `AdSlots` và lúc `UPDATE` giảm `duration_seconds` trên `Episodes`).
   - **Đồng nhất Creator:** Chỉ được gắn `AdContracts` của Creator vào `Episodes` thuộc kênh của chính Creator đó.
   - **Vị trí phát hợp lệ:** `AdSlots.start_offset_seconds` không được vượt quá `Episodes.duration_seconds`.
