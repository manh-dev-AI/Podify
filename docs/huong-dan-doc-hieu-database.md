# Hướng Dẫn Đọc Hiểu Toàn Bộ Cơ Sở Dữ Liệu Podify (Từ Con Số 0)

Tài liệu này giải thích chi tiết cách đọc hiểu file [full_schema.sql](file:///d:/BTL_DB/Podify/database/schema/full_schema.sql) (12 bảng, chuẩn 3NF, MySQL 8.0) và sơ đồ E-R [podify_erd.png](file:///d:/BTL_DB/Podify/database/erd/podify_erd.png), giúp bạn hiểu rõ **từng từ khóa trong bảng SQL**, **cách các bảng liên kết với nhau**, và **tại sao lại là quan hệ `1-1`, `1-N`, `M-N`**.

---

## Phần 1: Giải mã từng thành phần trong một bảng SQL

Hãy nhìn vào ví dụ thật từ bảng `Episodes` và `Users` trong [full_schema.sql](file:///d:/BTL_DB/Podify/database/schema/full_schema.sql):

```sql
CREATE TABLE Episodes (
    episode_id INT AUTO_INCREMENT PRIMARY KEY,
    channel_id INT NOT NULL,
    title VARCHAR(255) NOT NULL,
    description TEXT NULL,
    audio_url VARCHAR(255) NOT NULL,
    duration_seconds INT NOT NULL,
    published_at DATETIME NULL,
    status ENUM('draft', 'published', 'archived') NOT NULL DEFAULT 'draft',
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT CHK_Episodes_Duration CHECK (duration_seconds > 0),
    CONSTRAINT FK_Episodes_Channels FOREIGN KEY (channel_id)
        REFERENCES PodcastChannels(channel_id) ON DELETE CASCADE,
    INDEX IDX_Episodes_Channel_Status_Duration (channel_id, status, duration_seconds)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
```

### 1.1. Các kiểu dữ liệu (Data Types) thường gặp trong Podify
| Kiểu dữ liệu | Ý nghĩa | Ví dụ dùng trong Podify |
| :--- | :--- | :--- |
| `INT` | Số nguyên (tối đa ~2 tỷ) | `user_id`, `duration_seconds` (thời lượng tính bằng giây), `impressions` |
| `TINYINT` | Số nguyên rất nhỏ (-128 đến 127) | `score` trong `Ratings` (chỉ cần lưu từ 1 đến 5, dùng `TINYINT` tiết kiệm bộ nhớ hơn `INT`) |
| `DECIMAL(12, 2)` | Số thập phân chính xác tuyệt đối (12 chữ số, 2 số sau dấu phẩy) | `contract_value`, `amount` trong `AdRevenue` và `Donations`. *(Lưu tiền bắt buộc dùng `DECIMAL`, không dùng `FLOAT` vì `FLOAT` bị sai số làm tròn).* |
| `VARCHAR(n)` | Chuỗi ký tự ngắn có độ dài tối đa `n` | `username VARCHAR(50)`, `email VARCHAR(100)`, `title VARCHAR(255)` |
| `TEXT` | Văn bản dài không giới hạn độ dài ngắn như `VARCHAR` | `bio`, `description`, `comment` |
| `BOOLEAN` | Đúng/Sai (MySQL lưu ngầm là `0` hoặc `1`) | `verified`, `notify_enabled`, `is_completed` |
| `ENUM(...)` | Chỉ cho phép chọn 1 trong các giá trị cố định liệt kê sẵn | `role ENUM('user','creator','admin')`, `status ENUM('draft','published','archived')` |
| `DATETIME` | Ngày + Giờ đầy đủ (`YYYY-MM-DD HH:MM:SS`) | `created_at`, `published_at`, `donated_at` |
| `DATE` | Chỉ lưu Ngày (`YYYY-MM-DD`), không lưu giờ | `start_date`, `end_date` (hợp đồng), `revenue_date` |

### 1.2. Các ràng buộc cột (Constraints) — "Luật bảo vệ dữ liệu"
- **`PRIMARY KEY` (`PK` — Khóa chính):** Cột định danh duy nhất mỗi dòng trong bảng (ví dụ `episode_id`). Không bao giờ được trùng và không bao giờ được trống (`NULL`).
- **`AUTO_INCREMENT`:** Khi thêm dòng mới (`INSERT`), MySQL tự động đếm tăng dần `1, 2, 3...`, không cần tự nhập ID bằng tay.
- **`NOT NULL` vs `NULL`:**
  - `NOT NULL`: Bắt buộc phải có dữ liệu (ví dụ `title`, `audio_url`).
  - `NULL`: Được phép để trống. Ví dụ: `published_at DATETIME NULL` vì khi tập podcast mới tạo ở trạng thái `'draft'` (bản nháp) thì **chưa có ngày xuất bản**.
- **`UNIQUE` (`UQ` — Duy nhất):** Cấm trùng lặp giá trị giữa các dòng. Ví dụ: `email` trong `Users`, `contract_code` trong `AdContracts`.
- **`DEFAULT ...`:** Nếu lúc `INSERT` không truyền giá trị, MySQL tự điền giá trị mặc định (ví dụ `DEFAULT 'draft'`, `DEFAULT CURRENT_TIMESTAMP` tự lấy giờ hiện tại).
- **`CHECK (...)`:** Kiểm tra điều kiện logic trước khi cho lưu:
  - `CHECK (duration_seconds > 0)`: Thời lượng tập không thể âm hoặc bằng 0.
  - `CHECK (score BETWEEN 1 AND 5)`: Điểm đánh giá chỉ được từ 1 đến 5 sao.
  - `CHECK (end_date >= start_date)`: Ngày kết thúc hợp đồng không được trước ngày bắt đầu.

### 1.3. Khóa ngoại (`FOREIGN KEY` — `FK`) & Hành vi khi xóa (`ON DELETE`)
`FOREIGN KEY` là sợi dây nối từ bảng con trỏ về `PRIMARY KEY` của bảng cha:
```sql
CONSTRAINT FK_Episodes_Channels FOREIGN KEY (channel_id)
    REFERENCES PodcastChannels(channel_id) ON DELETE CASCADE
```
- **Ý nghĩa kiểm tra:** Bạn **không thể** chèn một `Episode` với `channel_id = 999` nếu trong bảng `PodcastChannels` chưa tồn tại kênh số `999`.
- **Hai kiểu xử lý khi xóa bảng cha:**
  1. **`ON DELETE CASCADE`:** Xóa cha thì xóa luôn con. Ví dụ: Xóa một `PodcastChannels` → toàn bộ `Episodes` và `Subscriptions` của kênh đó tự động bị xóa theo, tránh dữ liệu "mồ côi".
  2. **`ON DELETE SET NULL`:** Xóa cha nhưng **giữ lại dòng con** và gán cột FK thành `NULL`. Trong Podify dùng ở 2 chỗ rất thực tế:
     - `AdRevenue.slot_id`: Nếu một vị trí quảng cáo (`AdSlots`) bị gỡ bỏ, dòng doanh thu trong sổ sách `AdRevenue` vẫn phải giữ nguyên để kế toán đối soát.
     - `Donations.episode_id`: Nếu tập podcast bị xóa, lịch sử giao dịch ủng hộ Creator trong `Donations` vẫn được giữ lại.

### 1.4. `INDEX`, `ENGINE=InnoDB` và `utf8mb4`
- **`INDEX`:** Giống như mục lục ở đầu sách, giúp MySQL tìm nhanh dữ liệu mà không cần quét từ dòng đầu đến dòng cuối (ví dụ `IDX_Episodes_Channel_Status_Duration` tăng tốc truy vấn `Q1`).
- **`ENGINE=InnoDB`:** Bộ máy lưu trữ bắt buộc của MySQL để dùng được `FOREIGN KEY` và Transaction (an toàn dữ liệu).
- **`DEFAULT CHARSET=utf8mb4`:** Bảng mã chuẩn để lưu tiếng Việt có dấu và emoji không bị lỗi thành dấu `?`.

---

## Phần 2: Cách hiểu các kiểu liên kết (`1-1`, `1-N`, `M-N`) và lý do thiết kế

> **Quy tắc vàng khi đọc & thiết kế SQL:**  
> Trong mọi quan hệ **1 – Nhiều (`1 : N`)**, cột **Khóa ngoại (`FK`) luôn nằm ở bảng bên Nhiều (`N`)**, trỏ về **Khóa chính (`PK`) của bảng bên Một (`1`)**.

---

### Kiểu 1: Quan hệ `1 : 0..1` (Một – Tối đa Một)
**Ví dụ trong Podify:** `Users` **1 —— 0..1** `Creators`

- **Đọc bằng tiếng Việt:**
  - Một `User` có thể không có hồ sơ Creator (nếu chỉ nghe podcast), hoặc có **tối đa 1** hồ sơ `Creator`.
  - Ngược lại, một `Creator` **bắt buộc** phải thuộc về đúng **1** `User`.
- **Cách SQL thực hiện điều này:**
  Trong bảng `Creators`:
  ```sql
  user_id INT NOT NULL UNIQUE,
  CONSTRAINT FK_Creators_Users FOREIGN KEY (user_id) REFERENCES Users(user_id)
  ```
  Bình thường một `FOREIGN KEY` sẽ tạo ra quan hệ `1 : N`. Nhưng vì gắn thêm từ khóa **`UNIQUE`** lên `user_id`, MySQL sẽ **cấm tạo 2 dòng `Creators` trỏ về cùng 1 `user_id`**. Thế là `1 : N` bị ép thành **`1 : 0..1`**!
- **Tại sao không gộp chung cột `bio`, `verified` vào bảng `Users` luôn cho gọn?**
  - Nếu gộp vào `Users`, thì 90% người dùng chỉ đi nghe podcast sẽ có các cột `display_name`, `bio`, `verified` bị bỏ trống (`NULL`) hàng loạt. Tách riêng bảng `Creators` giúp database gọn gàng, phân quyền rõ ràng và đạt chuẩn **3NF**.

---

### Kiểu 2: Quan hệ `1 : N` (Một – Nhiều)
Đây là quan hệ phổ biến nhất trong cơ sở dữ liệu quan hệ:

| Bảng bên `1` (Cha) | Bảng bên `N` (Con giữ `FK`) | Giải thích nghiệp vụ |
| :--- | :--- | :--- |
| `Creators` | `PodcastChannels` (`creator_id`) | 1 Creator quản lý nhiều Kênh; 1 Kênh chỉ thuộc 1 Creator. |
| `PodcastChannels` | `Episodes` (`channel_id`) | 1 Kênh có nhiều Tập; 1 Tập chỉ thuộc 1 Kênh. |
| `Advertisements` | `AdContracts` (`ad_id`) | 1 mẫu Quảng cáo có thể ký nhiều Hợp đồng; 1 Hợp đồng gắn với 1 mẫu Quảng cáo. |
| `Creators` | `AdContracts` (`creator_id`) | 1 Creator có thể ký nhiều Hợp đồng quảng cáo. |
| `AdContracts` | `AdRevenue` (`contract_id`) | 1 Hợp đồng phát sinh nhiều dòng Doanh thu theo từng ngày (`revenue_date`). |
| `Users` | `Donations` (`donor_user_id`) | 1 User có thể Donate nhiều lần. |
| `Creators` | `Donations` (`creator_id`) | 1 Creator có thể nhận nhiều lượt Donate. |

---

### Kiểu 3: Quan hệ `0..1 : N` (Tùy chọn Một – Nhiều)
**Ví dụ trong Podify:**
1. `Episodes` **0..1 —— N** `Donations` (`episode_id INT NULL`)
   - **Tại sao là `0..1`?** Vì người nghe có thể vào thẳng trang của Creator để donate ủng hộ chung (không gắn với tập nào → `episode_id` để `NULL`), hoặc đang nghe một tập hay quá nên donate ngay tại tập đó (`episode_id` có giá trị).
2. `AdSlots` **0..1 —— N** `AdRevenue` (`slot_id INT NULL`)
   - **Tại sao là `0..1`?** Doanh thu có thể ghi nhận chung theo hợp đồng hoặc theo từng slot, và khi xóa slot (`ON DELETE SET NULL`) thì `slot_id` trở về `NULL`.

---

### Kiểu 4: Quan hệ `M : N` (Nhiều – Nhiều) → Tách thành **Bảng trung gian**
Trong SQL, bạn **không thể** nối trực tiếp 2 bảng theo kiểu Nhiều – Nhiều (ví dụ không thể nhét 100 `channel_id` vào 1 ô của bảng `Users` vì sẽ vi phạm chuẩn **1NF**).  
**Giải pháp bắt buộc:** Tạo ra **1 bảng trung gian** nằm ở giữa, biến quan hệ `M : N` thành **hai quan hệ `1 : N`**.

Trong Podify có **4 bảng trung gian** như vậy:

1. **`Subscriptions` = `Users` (`M`) ↔ `PodcastChannels` (`N`)**
   - 1 User theo dõi nhiều Kênh; 1 Kênh có nhiều User theo dõi.
   - Có thêm ràng buộc `UNIQUE (user_id, channel_id)` để 1 người không thể bấm Subscribe trùng cùng 1 kênh 2 lần.
2. **`ListeningHistory` = `Users` (`M`) ↔ `Episodes` (`N`)**
   - 1 User nghe nhiều Tập; 1 Tập được nhiều User nghe.
   - **Không đặt `UNIQUE (user_id, episode_id)`** (hoặc cho phép cập nhật/lưu nhiều lần nghe) để ghi nhận nhiều lượt nghe của cùng một user theo thời gian, phục vụ đếm tổng lượt nghe (`Q5`, `Q6`) và lưu vị trí dừng (`last_position_seconds`).
3. **`Ratings` = `Users` (`M`) ↔ `Episodes` (`N`)**
   - 1 User đánh giá nhiều Tập; 1 Tập nhận đánh giá từ nhiều User.
   - Đặt `UNIQUE (user_id, episode_id)` để mỗi User chỉ chấm điểm **1 lần** cho mỗi Tập (muốn đổi điểm thì cập nhật lại dòng cũ).
4. **`AdSlots` = `AdContracts` (`M`) ↔ `Episodes` (`N`)**
   - 1 Hợp đồng quảng cáo có thể phát ở nhiều Tập khác nhau; 1 Tập có thể chèn nhiều Hợp đồng ở các vị trí `pre-roll` (đầu tập), `mid-roll` (giữa tập), `post-roll` (cuối tập).
   - Đặt `UNIQUE (contract_id, episode_id, slot_position)` để cùng 1 hợp đồng không bị chèn trùng 2 lần vào đúng 1 vị trí trên cùng 1 tập.
   - **Tại sao tách `AdContracts` và `AdSlots`?** Vì hợp đồng (`AdContracts`) là thỏa thuận tiền bạc/thời hạn với Creator, còn `AdSlots` là vị trí phát thực tế trong từng tập Podcast. Tách ra mới gắn được Trigger: *Episode dưới 20 phút chỉ được gắn tối đa 3 hợp đồng khác nhau*.

---

## Phần 3: Bảng tra cứu nhanh toàn bộ 12 bảng & 3 phân hệ

| Phân hệ | Bảng | Khóa chính (`PK`) | Khóa ngoại (`FK`) trỏ đi đâu |
| :--- | :--- | :--- | :--- |
| **Module 01 (Mạnh)** | `Users` | `user_id` | *(Bảng gốc, không có FK)* |
| **Module 01 (Mạnh)** | `Creators` | `creator_id` | `user_id` → `Users` (`1:0..1`) |
| **Module 01 (Mạnh)** | `PodcastChannels` | `channel_id` | `creator_id` → `Creators` (`1:N`) |
| **Module 01 (Mạnh)** | `Episodes` | `episode_id` | `channel_id` → `PodcastChannels` (`1:N`) |
| **Module 02 (Quân)** | `Subscriptions` | `subscription_id` | `user_id` → `Users`, `channel_id` → `PodcastChannels` |
| **Module 02 (Quân)** | `ListeningHistory` | `history_id` | `user_id` → `Users`, `episode_id` → `Episodes` |
| **Module 02 (Quân)** | `Ratings` | `rating_id` | `user_id` → `Users`, `episode_id` → `Episodes` |
| **Module 03 (Quang)** | `Advertisements` | `ad_id` | *(Bảng gốc kho quảng cáo, không có FK)* |
| **Module 03 (Quang)** | `AdContracts` | `contract_id` | `ad_id` → `Advertisements`, `creator_id` → `Creators` |
| **Module 03 (Quang)** | `AdSlots` | `slot_id` | `contract_id` → `AdContracts`, `episode_id` → `Episodes` |
| **Module 03 (Quang)** | `AdRevenue` | `revenue_id` | `contract_id` → `AdContracts`, `slot_id` → `AdSlots` |
| **Module 03 (Quang)** | `Donations` | `donation_id` | `donor_user_id` → `Users`, `creator_id` → `Creators`, `episode_id` → `Episodes` |

---

## Phần 4: Cách đọc nhanh sơ đồ E-R (`podify_erd.png`) khi thuyết trình

Khi nhìn vào [podify_erd.png](file:///d:/BTL_DB/Podify/database/erd/podify_erd.png), bạn chỉ cần nhớ quy tắc đọc ký hiệu **Crow's Foot (Chân chim)**:
- **Đầu có 1 gạch thẳng `|`:** Bắt buộc đúng **1** bản ghi (bên Cha).
- **Đầu có vòng tròn + gạch `o|`:** Có thể **0 hoặc 1** bản ghi (tùy chọn).
- **Đầu có hình chân chim 3 nhánh `o<`:** Có **0 hoặc nhiều (`N`)** bản ghi (bên Con giữ khóa ngoại).

### Gợi ý 4 câu hỏi giảng viên hay hỏi khi bảo vệ:
1. *"Tại sao lại tách `Users` và `Creators`?"* → Để đạt chuẩn **3NF**, không làm cột `bio`, `verified` bị `NULL` hàng loạt đối với người nghe thường, và dùng `UNIQUE(user_id)` tạo quan hệ `1 : 0..1`.
2. *"Tại sao `ListeningHistory` và `Ratings` đều nối `Users` với `Episodes` mà không gộp làm 1 bảng?"* → Vì 1 User có thể nghe 1 tập **nhiều lần** ở các thời điểm khác nhau (không `UNIQUE`), nhưng chỉ được chấm điểm **1 lần** cho mỗi tập (`UNIQUE(user_id, episode_id)` trong `Ratings`). Tách ra giúp tách biệt dữ liệu lịch sử và dữ liệu đánh giá.
3. *"Tại sao xóa `AdSlots` hoặc `Episodes` lại dùng `ON DELETE SET NULL` ở `AdRevenue` và `Donations`?"* → Vì đây là dữ liệu tài chính/sao kê, xóa nội dung không được làm mất lịch sử doanh thu và tiền ủng hộ đã phát sinh.
4. *"Tại sao biết một tập dưới 20 phút có quá 3 hợp đồng hay không?"* → Dựa vào `Episodes.duration_seconds < 1200` kết hợp đếm `COUNT(DISTINCT contract_id)` trong bảng `AdSlots` thông qua MySQL Trigger.
