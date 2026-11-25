# Testing Report — Podify

Báo cáo tổng hợp chiến lược kiểm thử, danh sách Test Cases và hướng dẫn thực thi cho 4 tầng: **Database (Schema, Constraints, Triggers, Q1–Q8)**, **RESTful API**, và **Cross-Module Integration**.

---

## 1. Bộ kiểm thử tự động trong dự án (`tests/`)

| Tập tin | Phạm vi kiểm thử |
| :--- | :--- |
| [test_database_suite.py](file:///c:/Users/win10/Desktop/demo/tests/database/test_database_suite.py) | Kiểm tra tĩnh toàn bộ 12 bảng, 3 Triggers, Seed 12 bảng, 8 Queries `Q1–Q8`, file ERD; đồng thời chạy kiểm thử trực tiếp trên **MySQL 8.0** khi bật `TEST_MYSQL=1`. |
| [test_api_endpoints.py](file:///c:/Users/win10/Desktop/demo/tests/api/test_api_endpoints.py) | Kiểm tra toàn bộ Flask API routes: Auth/Login, phân quyền Role (`401`/`403`), bắt lỗi trùng lặp (`409`), validate `score` 1–5 (`400`), mapping lỗi Trigger (`400 DB_TRIGGER_VIOLATION`), và Query Runner `Q1–Q8`. |
| [test_end_to_end_flow.py](file:///c:/Users/win10/Desktop/demo/tests/integration/test_end_to_end_flow.py) | Kịch bản tích hợp xuyên 3 phân hệ: Creator tạo Channel & Episode (`Content`) → User nghe & chấm điểm (`Listening`) → User ủng hộ & kiểm tra báo cáo (`Ads & Analytics`). |
| [podify_postman_collection.json](file:///c:/Users/win10/Desktop/demo/tests/api/podify_postman_collection.json) | Bộ Postman Collection sẵn sàng import để demo từng request trực tiếp. |

---

## 2. Kịch bản kiểm thử trọng tâm (Test Cases)

### 2.1. Kiểm thử Ràng buộc & Trigger CSDL (`Database`)
| Mã TC | Tình huống kiểm thử | Kỳ vọng MySQL 8.0 |
| :--- | :--- | :--- |
| `DB-01` | Chạy `full_schema.sql` → `01_ad_contract_limit.sql` → `full_seed.sql` | Tạo đủ 12 bảng, 3 triggers, nạp dữ liệu mẫu không lỗi FK. |
| `DB-02` | Đăng ký trùng `(user_id=4, channel_id=1)` trong `Subscriptions` | Bị chặn bởi `UQ_Subscriptions_User_Channel` (errno `1062` → API trả `409`). |
| `DB-03` | Đánh giá `score = 6` hoặc `duration_seconds = 0` hoặc `amount = -100` | Bị chặn bởi `CHECK` constraint (errno `3819`). |
| `DB-04` | Gắn hợp đồng thứ 4 (`contract_id=4`) vào Episode #3 (`600s < 20 phút`, đã có 3 HĐ) | Trigger `TRG_AdSlots_Limit_Contracts_BI` chặn với `SQLSTATE '45000'` (errno `1644` → API trả `400`). |
| `DB-05` | Gắn 4 hợp đồng (`1, 2, 3, 4`) vào Episode #4 (`2400s >= 20 phút`) | Chấp nhận thành công (chứng minh điều kiện biên `< 1200s` chính xác). |
| `DB-06` | Cập nhật Episode #4 giảm `duration_seconds` xuống `900s` khi đang có 4 HĐ | Trigger `TRG_Episodes_Duration_Limit_BU` chặn với `SQLSTATE '45000'` (errno `1644`). |

### 2.2. Kiểm thử 8 Truy vấn Nghiệp vụ (`Q1`–`Q8`) với bộ Seed chuẩn
| Câu truy vấn | Kết quả kiểm chứng trên bộ Seed |
| :--- | :--- |
| `Q1` | Trả về **2 tập** của Channel 1 có thời lượng 15–30p: Ep #1 (`1200s`) và Ep #2 (`1500s`). |
| `Q2` | Trả về **3 quảng cáo** xuất hiện trong `EP99`: `FPT Cloud`, `TopCV`, `Vietcombank`. |
| `Q3` | Thống kê đúng số subscriber mới trong tháng hiện tại cho 3 kênh (Channel 1: `3`, Channel 2: `1`, Channel 3: `1`). |
| `Q4` | Trả về duy nhất Channel #3 (`Trà Chiều Radio`) có điểm Rating trung bình `2.33 < 3.0`. |
| `Q5` | Liệt kê đủ 8 Episode kèm lượt nghe, trong đó Ep #4 (`Tối ưu chỉ mục Indexes`) hiển thị **`0` lượt nghe** nhờ `LEFT JOIN`. |
| `Q6` | Trả về các tập vượt trung bình các tập khác cùng kênh (Ep #1, Ep #2 thuộc Channel 1; Ep #5 thuộc Channel 2; Ep #6 thuộc Channel 3). |
| `Q7` | Trả về duy nhất tài khoản `le_c` (tạo > 6 tháng, chưa từng xuất hiện trong `Subscriptions`). |
| `Q8` | Tính doanh thu tháng và doanh thu tích lũy tăng dần qua từng tháng cho `Tech Talk VN` (4 tháng) và `Góc Tâm Sự` (3 tháng) bằng `SUM() OVER (PARTITION BY creator_id ORDER BY revenue_month)`. |

---

## 3. Hướng dẫn chạy kiểm thử

### Chạy kiểm thử cấu trúc SQL & API (không cần cấu hình mật khẩu MySQL)
```powershell
.\backend\venv\Scripts\python.exe -m unittest discover -s tests -p "test_*.py" -v
```

### Chạy toàn bộ bao gồm kiểm thử trực tiếp trên MySQL 8.0
1. Copy `.env.example` thành `.env` và điền `DB_PASSWORD` của máy bạn.
2. Chạy kèm biến môi trường `TEST_MYSQL=1`:
```powershell
$env:TEST_MYSQL="1"
.\backend\venv\Scripts\python.exe -m unittest discover -s tests -p "test_*.py" -v
```
