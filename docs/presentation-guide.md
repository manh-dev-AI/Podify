# Hướng dẫn Thuyết trình & Bảo vệ Đồ án — Podify

Tài liệu tóm tắt toàn bộ những gì đã xây dựng, kịch bản demo trực tiếp trên MySQL Workbench + Web App, và bộ câu hỏi phản biện thường gặp khi thuyết trình môn Cơ sở dữ liệu / Web Database.

---

## 1. Tóm tắt nhanh những điểm ăn điểm của dự án

1. **Một Cơ sở dữ liệu tập trung (One Shared Database — 12 bảng, MySQL 8.0):**
   - Liên kết chặt chẽ cả 3 mảng nghiệp vụ thực tế: **Content Management (4 bảng)** ↔ **Listening & Interaction (3 bảng)** ↔ **Ads & Analytics (5 bảng)**.
   - Chuẩn hóa **3NF triệt để**: Không lưu cột dẫn xuất (`listen_count`, `avg_rating`), không lưu khóa ngoại dư thừa gây phụ thuộc bắc cầu (`AdRevenue` không lặp lại `creator_id` mà nối qua `AdContracts`).
2. **Bảo vệ dữ liệu đa tầng (Database-level + API-level):**
   - Ràng buộc `UNIQUE`, `CHECK`, `FOREIGN KEY (ON DELETE CASCADE / SET NULL)`.
   - **3 MySQL Triggers** xử lý nghiệp vụ cốt lõi: giới hạn tối đa 3 hợp đồng quảng cáo cho Episode `< 20 phút`, đảm bảo hợp đồng cùng Creator với Episode, và chặn sửa giảm thời lượng Episode khi đã gắn > 3 hợp đồng.
3. **8 Câu truy vấn SQL nâng cao (`Q1`–`Q8`):**
   - Bao phủ đầy đủ kỹ thuật SQL: `INNER JOIN` 4 bảng (`Q2`), `LEFT JOIN` giữ bản ghi 0 lượt (`Q3`, `Q5`), `GROUP BY + HAVING` (`Q4`), `NOT EXISTS` (`Q7`), `CTE + Window Function OVER (PARTITION BY ... ORDER BY ...)` (`Q6`, `Q8`).
4. **Sản phẩm Web chạy thật xuyên suốt:**
   - Python Flask RESTful API + `mysql-connector-python` Connection Pool + Token Auth (`pbkdf2:sha256`).
   - Giao diện Dark/Light mode hiện đại, phát file MP3 thật qua HTML5 `<audio>`, có sẵn tab **SQL Queries (Q1–Q8)** và màn **Test Trigger** ngay trên trình duyệt.

---

## 2. Kịch bản Demo khi lên Thuyết trình (5–7 phút)

### Bước 1: Chuẩn bị trước giờ trình bày
1. Đảm bảo đã tạo `.env` từ `.env.example` và điền `DB_PASSWORD` đúng của MySQL local.
2. Chạy lệnh khởi tạo DB sạch + nạp dữ liệu mẫu:
   ```powershell
   .\backend\venv\Scripts\python.exe backend/init_db.py
   ```
3. Khởi động Backend + Frontend trên cùng 1 cổng `5000`:
   ```powershell
   .\backend\venv\Scripts\python.exe backend/app.py
   ```
4. Mở trình duyệt tại `http://127.0.0.1:5000` (kiểm tra góc phải trên hiện badge xanh **`MySQL · 12 bảng`**) và mở sẵn **MySQL Workbench** kèm sơ đồ [podify_erd.png](file:///c:/Users/win10/Desktop/demo/database/erd/podify_erd.png).

### Bước 2: Trình bày Phần Database (2.5 phút)
1. Chiếu sơ đồ ERD [podify_erd.png](file:///c:/Users/win10/Desktop/demo/database/erd/podify_erd.png) — chỉ rõ 3 cụm màu (Content – Listening – Ads) và giải thích quan hệ `Users (1:0..1) Creators`, `AdContracts (tầng thương mại) — (1:N) -> AdSlots (tầng vị trí trong Episode)`.
2. Mở MySQL Workbench (hoặc tab `Ads & Analytics -> SQL Queries` ngay trên Web):
   - Chạy **`Q5`** để cho thấy Tập #4 có `0` lượt nghe vẫn xuất hiện nhờ `LEFT JOIN`.
   - Chạy **`Q7`** để cho thấy chỉ trả về đúng user `le_c` (> 6 tháng, chưa từng Subscribe).
   - Chạy **`Q8`** để minh họa **Window Function** tính cột `cumulative_revenue` cộng dồn theo từng tháng cho từng Creator.

### Bước 3: Demo Tương tác Web & Trigger trực tiếp (2.5 phút)
1. Bấm nút tài khoản góc phải trên → chọn nhanh **`pham_d (user)`** (mật khẩu `123456`).
2. Vào **Home / Explore**:
   - Bấm lọc **"15–30 phút (Q1)"** để thấy lọc động từ MySQL.
   - Bấm **▶ Nghe** một tập để bật Mini Audio Player phát file MP3 thật, tua thanh tiến trình và vào tab **History** kiểm tra tiến trình vừa lưu vào `ListeningHistory`.
   - Bấm **★ Rate** chấm điểm và vào **Donate Creator** ủng hộ thử `50,000 đ`.
3. Chuyển sang tài khoản **`nguyenvan_a (creator)`** → vào **Ads & Analytics → Quảng cáo, Hợp đồng & Trigger**:
   - Chọn Hợp đồng **`CTR-2026-004`** và Episode **`#3 (600s < 20 phút)`** (đã có sẵn 3 hợp đồng `001, 002, 003`) → bấm **Gắn AdSlot vào Episode**.
   - **Kết quả:** Hệ thống báo lỗi đỏ trực tiếp từ MySQL Trigger (`1644`): *"Business Rule Violation: Episode duoi 20 phut (< 1200s) chi duoc gan toi da 3 hop dong quang cao."*
   - Sau đó thử gắn hợp đồng đó hoặc chỉ ra Episode **`#4 (2400s = 40 phút)`** đã gắn thành công 4 hợp đồng → khẳng định tính đúng đắn của điều kiện biên!

---

## 3. Bộ câu hỏi phản biện thường gặp & Gợi ý trả lời

1. **Hỏi: Tại sao lại tách `Users` và `Creators` thành 2 bảng thay vì gộp chung?**
   - *Trả lời:* Vì một số người dùng chỉ nghe (`role='user'`), không có hồ sơ Creator (`display_name`, `bio`, `verified`). Nếu gộp vào `Users` sẽ sinh ra nhiều giá trị `NULL` dư thừa và vi phạm **3NF** (các thuộc tính Creator phụ thuộc vào vai trò Creator). Tách thành `Creators` với `user_id UNIQUE FK` tạo quan hệ `1 : 0..1` chuẩn mực.
2. **Hỏi: Tại sao `AdContracts` không gắn trực tiếp `episode_id` mà phải qua `AdSlots`?**
   - *Trả lời:* Trong thực tế, một hợp đồng thương mại (`AdContracts`) ký giữa Creator và Nhãn hàng có giá trị, CPM và ngày hiệu lực áp dụng cho **nhiều tập Podcast**; ngược lại một tập Podcast có thể chèn nhiều vị trí quảng cáo (`pre-roll`, `mid-roll`, `post-roll`). `AdSlots` là bảng liên kết phân phối vị trí chèn quảng cáo theo từng tập, giúp không lặp lại dữ liệu hợp đồng (đảm bảo 3NF).
3. **Hỏi: Tại sao không tạo cột `listen_count` trong bảng `Episodes` cho nhanh mà phải đếm từ `ListeningHistory`?**
   - *Trả lời:* Cột `listen_count` là **thuộc tính dẫn xuất** có thể tính được từ `COUNT(history_id)` trong `ListeningHistory`. Lưu thêm cột dẫn xuất dễ gây sai lệch dữ liệu (Update Anomaly) nếu xóa/sửa lịch sử mà quên cập nhật lại. Khi dữ liệu lớn, hệ thống đã có `INDEX IDX_History_Episode` để tối ưu tốc độ `COUNT`.
4. **Hỏi: Vì sao trong Trigger đếm `COUNT(DISTINCT contract_id)` thay vì `COUNT(*)` trên `AdSlots`?**
   - *Trả lời:* Đề bài yêu cầu tối đa **3 hợp đồng** cho mỗi Episode dưới 20 phút. Một hợp đồng có thể xuất hiện ở cả vị trí `pre-roll` và `post-roll` trong cùng 1 tập, nên phải dùng `COUNT(DISTINCT contract_id)` để đếm đúng số *hợp đồng* khác nhau chứ không đếm nhầm số *vị trí phát*.
5. **Hỏi: Nếu người dùng tạo Episode 30 phút, gắn 4 hợp đồng rồi sửa thời lượng Episode xuống 10 phút thì Trigger `AdSlots` có chặn được không?**
   - *Trả lời:* Nếu chỉ viết Trigger trên `AdSlots` thì sẽ bị lọt trường hợp này! Vì vậy nhóm đã viết thêm Trigger **`TRG_Episodes_Duration_Limit_BU` (`BEFORE UPDATE ON Episodes`)** để kiểm tra số hợp đồng hiện có và chặn hành động giảm thời lượng xuống dưới 1200 giây nếu đã có > 3 hợp đồng.
6. **Hỏi: Trong câu `Q3` và `Q5`, tại sao phải dùng `LEFT JOIN` và trong `Q3` lại đặt điều kiện tháng ở mệnh đề `ON` thay vì `WHERE`?**
   - *Trả lời:* `LEFT JOIN` giữ lại cả những Channel chưa có subscriber mới (`Q3`) hoặc Episode có `0` lượt nghe (`Q5`). Riêng `Q3`, nếu đặt `MONTH(s.subscribed_at) = ...` vào `WHERE`, các dòng bên phải bị `NULL` sẽ bị loại bỏ và `LEFT JOIN` biến thành `INNER JOIN` mất kênh có 0 subscriber mới; đặt trong `ON` mới giữ đủ tất cả kênh.
7. **Hỏi: Phân biệt `COUNT(*)` và `COUNT(lh.history_id)` trong `Q5`?**
   - *Trả lời:* Với Episode chưa từng có ai nghe, `LEFT JOIN` tạo ra 1 dòng có `lh.history_id` là `NULL`. Nếu dùng `COUNT(*)` sẽ đếm thành `1` (sai!), còn `COUNT(lh.history_id)` bỏ qua `NULL` nên trả về đúng `0`.
8. **Hỏi: Trong câu `Q6`, làm sao tính trung bình các Episode *khác* cùng Channel mà không tự tính chính nó vào trung bình?**
   - *Trả lời:* Nhóm dùng CTE đếm lượt nghe từng tập, sau đó dùng Window Function `(SUM(listen_count) OVER (PARTITION BY channel_id) - listen_count) / NULLIF(COUNT(*) OVER (PARTITION BY channel_id) - 1, 0)` để trừ đúng giá trị của tập hiện tại ra khỏi tổng và mẫu số, đồng thời dùng `NULLIF(..., 0)` tránh lỗi chia cho 0 nếu kênh chỉ có 1 tập.
9. **Hỏi: Tại sao `AdRevenue` không chứa cột `creator_id`?**
   - *Trả lời:* Vì `AdRevenue` đã có `contract_id`, mà `AdContracts` đã xác định `creator_id`. Nếu lưu thêm `creator_id` ở `AdRevenue` sẽ gây **phụ thuộc bắc cầu** (`revenue_id → contract_id → creator_id`), vi phạm **3NF**.
10. **Hỏi: Nếu kết nối Web với Database gặp lỗi hoặc MySQL chưa chạy thì hệ thống xử lý ra sao?**
    - *Trả lời:* Tầng `backend/config/db.py` bắt toàn bộ mã lỗi `mysql-connector-python` (`1062`, `1644`, `3819`, `2003`...) và chuyển qua Global Error Handler trả JSON có cấu trúc kèm HTTP status phù hợp (`409`, `400`, `503`) chứ không crash server.
