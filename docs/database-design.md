# Database Design & Normalization (3NF) — Podify

Tài liệu thiết kế Cơ sở dữ liệu quan hệ cho hệ thống **Podify** trên **MySQL 8.0** theo mô hình **One Shared Database (`podify_db` — 12 bảng)**, đảm bảo chuẩn hóa **3NF**, toàn vẹn khóa ngoại và thực thi quy tắc nghiệp vụ bằng Constraints & Triggers.

- Sơ đồ ERD tổng thể: [podify_erd.png](file:///c:/Users/win10/Desktop/demo/database/erd/podify_erd.png) | [podify_erd.svg](file:///c:/Users/win10/Desktop/demo/database/erd/podify_erd.svg)
- Script tạo bảng chính thức: [full_schema.sql](file:///c:/Users/win10/Desktop/demo/database/schema/full_schema.sql)
- Script Trigger: [01_ad_contract_limit.sql](file:///c:/Users/win10/Desktop/demo/database/triggers/01_ad_contract_limit.sql)
- Script dữ liệu mẫu: [full_seed.sql](file:///c:/Users/win10/Desktop/demo/database/seed/full_seed.sql)

---

## 1. Tổng quan 12 bảng theo 3 phân hệ

| Phân hệ | Chủ sở hữu | Các bảng (Tổng: 12) |
| :--- | :--- | :--- |
| **Module 01: Content Management** | Mạnh (Schema Owner) | `Users`, `Creators`, `PodcastChannels`, `Episodes` (4 bảng) |
| **Module 02: Listening & Interaction** | Quân | `Subscriptions`, `ListeningHistory`, `Ratings` (3 bảng) |
| **Module 03: Ads & Analytics** | Quang | `Advertisements`, `AdContracts`, `AdSlots`, `AdRevenue`, `Donations` (5 bảng) |

---

## 2. Từ điển dữ liệu chi tiết (Data Dictionary)

### 2.1. Module 01 — Content Management ([01_users_content.sql](file:///c:/Users/win10/Desktop/demo/database/schema/01_users_content.sql))
1. **`Users`**: `user_id (PK)`, `username (UQ)`, `email (UQ)`, `password_hash`, `full_name`, `role ENUM('user','creator','admin')`, `avatar_url`, `created_at`, `updated_at`.
2. **`Creators`**: `creator_id (PK)`, `user_id (FK -> Users, UQ)`, `display_name`, `bio`, `verified`, `created_at`. Quan hệ **1 : 0..1** với `Users`.
3. **`PodcastChannels`**: `channel_id (PK)`, `creator_id (FK -> Creators)`, `title`, `description`, `category`, `cover_image_url`, `created_at`, `updated_at`. Quan hệ **1 : N** với `Creators`.
4. **`Episodes`**: `episode_id (PK)`, `channel_id (FK -> PodcastChannels)`, `title`, `description`, `audio_url`, `duration_seconds (CHECK > 0)`, `published_at`, `status ENUM('draft','published','archived')`, `created_at`. Quan hệ **1 : N** với `PodcastChannels`.

### 2.2. Module 02 — Listening & User Interaction ([02_listening.sql](file:///c:/Users/win10/Desktop/demo/database/schema/02_listening.sql))
5. **`Subscriptions`**: `subscription_id (PK)`, `user_id (FK -> Users)`, `channel_id (FK -> PodcastChannels)`, `subscribed_at`, `notify_enabled`. Ràng buộc `UQ_Subscriptions_User_Channel(user_id, channel_id)`.
6. **`ListeningHistory`**: `history_id (PK)`, `user_id (FK -> Users)`, `episode_id (FK -> Episodes)`, `last_position_seconds (CHECK >= 0)`, `is_completed`, `listened_at`, `updated_at`. Mỗi dòng đại diện cho 1 phiên nghe, giúp tính tổng lượt nghe chính xác bằng `COUNT(history_id)` mà không lưu cột dẫn xuất `listen_count`.
7. **`Ratings`**: `rating_id (PK)`, `user_id (FK -> Users)`, `episode_id (FK -> Episodes)`, `score (CHECK BETWEEN 1 AND 5)`, `comment`, `created_at`, `updated_at`. Ràng buộc `UQ_Ratings_User_Episode(user_id, episode_id)`.

### 2.3. Module 03 — Advertisement & Analytics ([03_advertisement.sql](file:///c:/Users/win10/Desktop/demo/database/schema/03_advertisement.sql))
8. **`Advertisements`**: `ad_id (PK)`, `advertiser_name`, `title`, `description`, `ad_audio_url`, `target_url`, `duration_seconds (CHECK > 0)`, `status ENUM('active','paused','archived')`, `created_at`.
9. **`AdContracts`**: `contract_id (PK)`, `ad_id (FK -> Advertisements)`, `creator_id (FK -> Creators)`, `contract_code (UQ)`, `contract_value (CHECK >= 0)`, `cpm_rate (CHECK >= 0)`, `start_date`, `end_date (CHECK >= start_date)`, `status ENUM('draft','active','completed','cancelled')`, `created_at`.
10. **`AdSlots`**: `slot_id (PK)`, `contract_id (FK -> AdContracts)`, `episode_id (FK -> Episodes)`, `slot_position ENUM('pre-roll','mid-roll','post-roll')`, `start_offset_seconds (CHECK >= 0)`, `status ENUM('scheduled','active','paused')`, `created_at`. Ràng buộc `UQ_AdSlots_Contract_Episode_Pos(contract_id, episode_id, slot_position)`.
11. **`AdRevenue`**: `revenue_id (PK)`, `contract_id (FK -> AdContracts)`, `slot_id (FK -> AdSlots, ON DELETE SET NULL)`, `revenue_date`, `impressions (CHECK >= 0)`, `amount (CHECK >= 0)`, `notes`, `created_at`.
12. **`Donations`**: `donation_id (PK)`, `donor_user_id (FK -> Users)`, `creator_id (FK -> Creators)`, `episode_id (FK -> Episodes, ON DELETE SET NULL)`, `amount (CHECK > 0)`, `message`, `donated_at`.

---

## 3. Phân tích tách bảng `AdContracts` và `AdSlots`

- **`AdContracts` (Tầng thương mại):** Thể hiện thỏa thuận kinh doanh giữa **Nhà quảng cáo (`Advertisements`)** và **Creator (`Creators`)** gồm mã hợp đồng, giá trị hợp đồng, đơn giá CPM và thời hạn hiệu lực. Một hợp đồng có thể tài trợ cho nhiều tập Podcast khác nhau của Creator đó.
- **`AdSlots` (Tầng phân phối kỹ thuật):** Gắn hợp đồng cụ thể (`contract_id`) vào từng **Episode (`episode_id`)** tại vị trí phát (`pre-roll`, `mid-roll`, `post-roll`) và mốc thời gian (`start_offset_seconds`).
- Việc tách riêng 2 bảng giúp tránh lặp lại thông tin giá trị/ngày hiệu lực hợp đồng trên từng tập, đồng thời thực thi được quy tắc "mỗi Episode < 20 phút gắn tối đa 3 hợp đồng khác nhau" thông qua `COUNT(DISTINCT contract_id)` trên `AdSlots`.

---

## 4. Chứng minh chuẩn hóa 1NF → 2NF → 3NF

1. **Dạng chuẩn 1 (1NF):**
   - Mọi bảng đều có Khóa chính đơn (`AUTO_INCREMENT INT PRIMARY KEY`).
   - Tất cả thuộc tính đều là giá trị nguyên tử (ví dụ: không lưu danh sách `tags` hay `ad_ids` phân cách bằng dấu phẩy trong một cột; `duration_seconds` lưu thống nhất bằng số nguyên giây).
2. **Dạng chuẩn 2 (2NF):**
   - Mọi bảng đã đạt 1NF và có khóa chính là khóa đơn (`*_id`), do đó không tồn tại phụ thuộc hàm bộ phận vào một phần của khóa chính.
   - Các bảng giao dịch nhiều-nhiều (`Subscriptions`, `Ratings`, `AdSlots`) đều dùng surrogate key làm PK và dùng ràng buộc `UNIQUE` trên các khóa ứng viên (`(user_id, channel_id)`, `(user_id, episode_id)`, `(contract_id, episode_id, slot_position)`), đảm bảo mọi thuộc tính không khóa phụ thuộc hoàn toàn vào toàn bộ khóa.
3. **Dạng chuẩn 3 (3NF — Không có phụ thuộc hàm bắc cầu):**
   - **Tách `Users` và `Creators`:** Thuộc tính riêng của nhà sáng tạo (`display_name`, `bio`, `verified`) chỉ phụ thuộc vào `creator_id`, không để chung trong `Users` (nếu để chung sẽ gây giá trị `NULL` hàng loạt và phụ thuộc điều kiện vào `role`).
   - **Không lưu cột dẫn xuất / bắc cầu:**
     - `PodcastChannels` và `Episodes` **không** lưu `subscriber_count`, `listen_count`, `avg_rating` (các giá trị này được tổng hợp động từ `Subscriptions`, `ListeningHistory`, `Ratings`), tránh bất thường cập nhật (Update Anomaly).
     - `AdRevenue` **không** lưu thừa `creator_id` hay `channel_id` vì `revenue_id → contract_id → creator_id` sẽ tạo ra phụ thuộc bắc cầu; khi tính `Q8` hệ thống `JOIN` qua `AdContracts`.
     - `Episodes` chỉ lưu `channel_id`, không lưu thừa `creator_id` (vì `episode_id → channel_id → creator_id`).
     - `Advertisements` chỉ lưu một tên đại diện `advertiser_name` gắn với quảng cáo (không lưu nhóm thông tin phụ thuộc bắc cầu như địa chỉ/SĐT/email của công ty quảng cáo, đảm bảo chặt chẽ trong phạm vi 12 bảng).

---

## 5. Thiết kế Index, Triggers & 8 Câu Truy vấn Nghiệp vụ

### 5.1. Chỉ mục (Indexes) tối ưu hiệu năng
- `IDX_Users_CreatedAt` hỗ trợ lọc User > 6 tháng trong `Q7`.
- `IDX_Episodes_Channel_Status_Duration` là Composite Index tối ưu trực tiếp cho `Q1` (`WHERE channel_id = ? AND status = 'published' AND duration_seconds BETWEEN 900 AND 1800`).
- `IDX_Subscriptions_Channel_Date` tối ưu thống kê subscriber theo tháng trong `Q3`.
- `IDX_History_User_Updated` và `IDX_History_Episode` tối ưu truy vấn lịch sử nghe của User và đếm lượt nghe (`Q5`, `Q6`).
- `IDX_AdRevenue_Contract_Date` hỗ trợ gom nhóm theo tháng và Window Function `Q8`.

### 5.2. MySQL Triggers ([01_ad_contract_limit.sql](file:///c:/Users/win10/Desktop/demo/database/triggers/01_ad_contract_limit.sql))
1. `TRG_AdSlots_Limit_Contracts_BI` (`BEFORE INSERT ON AdSlots`):
   - Kiểm tra hợp đồng (`AdContracts.creator_id`) thuộc cùng Creator sở hữu Episode (`PodcastChannels.creator_id`).
   - Kiểm tra `NEW.start_offset_seconds <= Episodes.duration_seconds`.
   - Nếu `duration_seconds < 1200` (dưới 20 phút), đếm `COUNT(DISTINCT contract_id)` trên `AdSlots` cho `NEW.episode_id`; nếu `NEW.contract_id` là hợp đồng mới và số hợp đồng đã đạt `>= 3`, phát sinh lỗi `SIGNAL SQLSTATE '45000'`.
2. `TRG_AdSlots_Limit_Contracts_BU` (`BEFORE UPDATE ON AdSlots`):
   - Tương tự khi cập nhật `episode_id`, `contract_id`, hoặc `start_offset_seconds` (loại trừ `OLD.slot_id`).
3. `TRG_Episodes_Duration_Limit_BU` (`BEFORE UPDATE ON Episodes`):
   - Chặn việc sửa `duration_seconds` xuống `< 1200` nếu Episode đó đang gắn hơn 3 hợp đồng quảng cáo khác nhau.

### 5.3. Tổng hợp 8 câu truy vấn (`database/queries/Q1.sql` – `Q8.sql`)
- **Q1** ([Q1.sql](file:///c:/Users/win10/Desktop/demo/database/queries/Q1.sql)): `INNER JOIN` + `BETWEEN 900 AND 1800` + `SEC_TO_TIME()`.
- **Q2** ([Q2.sql](file:///c:/Users/win10/Desktop/demo/database/queries/Q2.sql)): `INNER JOIN` 4 bảng (`Episodes` → `AdSlots` → `AdContracts` → `Advertisements`) tìm quảng cáo trong `EP99`.
- **Q3** ([Q3.sql](file:///c:/Users/win10/Desktop/demo/database/queries/Q3.sql)): `LEFT JOIN` với điều kiện tháng đặt trong mệnh đề `ON` để giữ lại cả kênh có 0 subscriber mới trong tháng.
- **Q4** ([Q4.sql](file:///c:/Users/win10/Desktop/demo/database/queries/Q4.sql)): `GROUP BY` + `HAVING AVG(r.score) < 3.0`.
- **Q5** ([Q5.sql](file:///c:/Users/win10/Desktop/demo/database/queries/Q5.sql)): `LEFT JOIN ListeningHistory` + `COUNT(lh.history_id)` để tập 0 lượt nghe vẫn hiển thị giá trị `0`.
- **Q6** ([Q6.sql](file:///c:/Users/win10/Desktop/demo/database/queries/Q6.sql)): CTE + Window Function tính trung bình các tập *khác* cùng kênh `(SUM - current) / NULLIF(COUNT - 1, 0)`.
- **Q7** ([Q7.sql](file:///c:/Users/win10/Desktop/demo/database/queries/Q7.sql)): `DATE_SUB(NOW(), INTERVAL 6 MONTH)` + `NOT EXISTS` tìm user lâu năm chưa từng subscribe.
- **Q8** ([Q8.sql](file:///c:/Users/win10/Desktop/demo/database/queries/Q8.sql)): CTE + `SUM(monthly_revenue) OVER (PARTITION BY creator_id ORDER BY revenue_month ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW)`.
