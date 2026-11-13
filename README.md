# Podify — Podcast & Audio Content Management System

> **Podify** là hệ thống quản lý nội dung Podcast, tương tác người nghe và phân tích doanh thu quảng cáo, được phát triển theo mô hình **Database-Driven Web Application** (nhóm 3 thành viên, lộ trình 14 ngày).

---

## 1. Định hướng đề tài

- **Mục tiêu:** Xây dựng một sản phẩm hoàn chỉnh kết nối chặt chẽ từ thiết kế cơ sở dữ liệu chuẩn hóa (**3NF**) đến tầng **RESTful API** và **giao diện Web**, phản ánh 3 mảng nghiệp vụ cốt lõi của một nền tảng Podcast thực tế:
  1. **Quản lý nội dung (Content Management):** Tài khoản người dùng, hồ sơ Creator, kênh Podcast và các tập (Episode).
  2. **Nghe & Tương tác người dùng (Listening & User Interaction):** Theo dõi kênh (Subscribe), trình phát Audio, lưu tiến trình nghe, lịch sử nghe và đánh giá Episode.
  3. **Quảng cáo & Phân tích kinh doanh (Advertisement & Analytics):** Quản lý quảng cáo, hợp đồng, vị trí chèn quảng cáo trong tập, ghi nhận doanh thu, lịch sử ủng hộ (Donation) và báo cáo thống kê.
- **Nguyên tắc thiết kế & Giới hạn phạm vi (14 ngày):**
  - **One Shared Database:** Cả hệ thống dùng chung **1 cơ sở dữ liệu duy nhất gồm 12 bảng** (không tách thành 3 database độc lập để đảm bảo khóa ngoại và tính toàn vẹn dữ liệu).
  - **Audio Player:** Sử dụng file `.mp3` mẫu lưu cục bộ trong dự án hoặc đường dẫn audio (chưa triển khai streaming phức tạp hay cloud storage).
  - **Authentication:** Xác thực cơ bản có phân quyền (`User` / `Creator`).
  - **Analytics & Donation:** Tập trung vào truy vấn SQL thống kê và biểu đồ cơ bản; không tích hợp cổng thanh toán thực tế cho Donation.

---

## 2. Hệ quản trị CSDL & Công nghệ sử dụng

### Tech Stack
| Thành phần | Công nghệ lựa chọn | Ghi chú |
| :--- | :--- | :--- |
| **Hệ quản trị CSDL (DBMS)** | **MySQL** | Chuẩn hóa 3NF, PK/FK, `UNIQUE`, `CHECK`, Index, Trigger, Window Function |
| **Backend** | **Python (Flask)** | Kiến trúc RESTful API (JSON), kết nối qua `mysql-connector-python`, chia module bằng Blueprints |
| **Frontend** | **HTML5, CSS3, JavaScript** | Giao diện đa trang nhẹ, tách JS/CSS theo từng phân hệ |
| **Version Control** | **Git & GitHub** | Mô hình *1 Repo – 3 Feature Branches – 1 Shared Database* |

### Công cụ nhóm chốt sử dụng
- **GitHub:** Quản lý mã nguồn, branch, Pull Request, Code Review và Issues.
- **Visual Studio Code:** Soạn thảo code Backend, Frontend, SQL và thao tác Git.
- **MySQL Workbench:** Quản trị MySQL, thiết kế mô hình ERD vật lý (EER Diagram), chạy SQL scripts và kiểm thử truy vấn.
- **Postman:** Kiểm thử các REST API endpoints (request, response, HTTP status codes).
- **Draw.io (`app.diagrams.net`):** Vẽ sơ đồ System Architecture và Flowchart nghiệp vụ (hoặc sơ đồ ERD khái niệm).

---

## 3. Cấu trúc thư mục & Tác dụng

```text
Podify/
├── README.md                        # Tài liệu tổng quan, định hướng, cấu trúc và phân công của dự án
├── .gitignore                       # Danh sách file/thư mục bỏ qua khi commit Git (.env, venv, __pycache__...)
├── .env.example                     # File mẫu các biến môi trường (DB_HOST, DB_PORT, DB_NAME, DB_USER...)
├── LICENSE                          # Giấy phép mã nguồn mở (MIT)
│
├── database/                        # Toàn bộ tài nguyên liên quan đến Cơ sở dữ liệu MySQL
│   ├── schema/                      # Script định nghĩa bảng, PK, FK, Constraints theo từng phân hệ
│   │   ├── 01_users_content.sql     # Bảng Users, Creators, PodcastChannels, Episodes (Mạnh)
│   │   ├── 02_listening.sql         # Bảng Subscriptions, ListeningHistory, Ratings (Quân)
│   │   ├── 03_advertisement.sql     # Bảng Advertisements, AdContracts, AdSlots, AdRevenue, Donations (Quang)
│   │   └── full_schema.sql          # Bản tổng hợp Schema chính thức toàn hệ thống (Schema Owner quản lý)
│   ├── seed/                        # Dữ liệu mẫu phục vụ kiểm thử và demo
│   │   ├── 01_seed_content.sql      # Dữ liệu mẫu Users, Creators, Channels, Episodes
│   │   ├── 02_seed_listening.sql    # Dữ liệu mẫu Subscriptions, ListeningHistory, Ratings
│   │   ├── 03_seed_ads.sql          # Dữ liệu mẫu Ads, Contracts, Slots, Revenue, Donations
│   │   └── full_seed.sql            # Bản tổng hợp nạp dữ liệu mẫu đúng thứ tự phụ thuộc FK
│   ├── queries/                     # 8 câu truy vấn SQL nghiệp vụ bắt buộc (Q1.sql -> Q8.sql)
│   ├── triggers/                    # Các MySQL Trigger đảm bảo Business Rules (vd: tối đa 3 hợp đồng cho Episode < 20p)
│   └── erd/                         # File sơ đồ ERD (MySQL Workbench .mwb / file ảnh xuất ra / Draw.io)
│
├── backend/                         # Tầng xử lý nghiệp vụ & RESTful API (Python Flask)
│   ├── app.py                       # Điểm khởi chạy ứng dụng Flask và đăng ký các module API
│   ├── requirements.txt             # Danh sách thư viện Python cần cài đặt (Flask, mysql-connector-python...)
│   ├── config/                      # Cấu hình kết nối MySQL và thiết lập ứng dụng
│   ├── common/                      # Tiện ích dùng chung (Auth/Session middleware, response format, error handler)
│   └── modules/                     # Mã nguồn API tách riêng theo 3 phân hệ
│       ├── content/                 # API tài khoản, Creator, Channel, Episode, Discovery & Search
│       ├── listening/               # API Subscribe, Listening History, Audio Progress, Ratings, Library
│       └── analytics/               # API Quảng cáo, Hợp đồng, AdSlots, Doanh thu, Donation & Thống kê
│
├── frontend/                        # Tầng giao diện người dùng (HTML/CSS/JS)
│   ├── index.html                   # Trang chủ / điểm vào ứng dụng Web
│   ├── assets/                      # Tài nguyên tĩnh dùng chung
│   │   ├── audio/                   # Các file MP3 mẫu dùng cho Audio Player và demo
│   │   └── images/                  # Ảnh bìa Podcast, avatar mẫu, icon
│   ├── css/                         # Stylesheet chia theo common và từng module
│   │   ├── common/
│   │   ├── content/
│   │   ├── listening/
│   │   └── analytics/
│   ├── js/                          # Logic gọi API & xử lý DOM theo common và từng module
│   │   ├── common/
│   │   ├── content/
│   │   ├── listening/
│   │   └── analytics/
│   └── pages/                       # Các trang giao diện chi tiết chia theo từng module
│       ├── content/
│       ├── listening/
│       └── analytics/
│
├── docs/                            # Tài liệu kỹ thuật và báo cáo đồ án
│   ├── requirements.md              # Phân tích yêu cầu và Business Rules
│   ├── architecture.md              # Kiến trúc hệ thống và mô tả API/Frontend flow
│   ├── database-design.md           # Thiết kế ERD, Relational Schema và báo cáo chuẩn hóa 3NF
│   ├── api-documentation.md         # Đặc tả chi tiết các REST API endpoints
│   └── testing-report.md            # Kịch bản kiểm thử và kết quả test hệ thống
│
└── tests/                           # Kịch bản và bộ kiểm thử
    ├── database/                    # Script kiểm tra Constraints, Trigger, Referential Integrity
    ├── api/                         # Postman Collection / test case kiểm thử API
    └── integration/                 # Kịch bản test luồng dữ liệu xuyên 3 module
```

---

## 4. Phân công công việc & Quy ước GitHub

### Chiến lược Branch (`One Repo – Three Feature Branches`)
| Branch | Người phụ trách | Mục đích |
| :--- | :--- | :--- |
| `main` | Cả nhóm (qua PR) | Phiên bản ổn định, sạch sẽ dùng để nộp và demo |
| `develop` | Cả nhóm (qua PR) | Nhánh tích hợp code từ 3 phân hệ trước khi đưa lên `main` |
| `feature/content-management` | **Mạnh** | Phát triển Module 01 (Content Management) |
| `feature/listening-interaction` | **Quân** | Phát triển Module 02 (Listening & User Interaction) |
| `feature/ads-analytics` | **Quang** | Phát triển Module 03 (Advertisement & Analytics) |

> **Quy tắc:** Không commit trực tiếp lên `main` hoặc `develop` sau khi đã khởi tạo khung dự án. Thành viên phát triển trên nhánh `feature/*` của mình và tạo **Pull Request** vào `develop` theo từng cột mốc (Schema → Backend → Frontend/Queries).

---

### Chi tiết nhiệm vụ 3 thành viên

#### Member 1 — Mạnh: **Content Management** (`feature/content-management`)
- **Database (4 bảng):** `Users`, `Creators`, `PodcastChannels`, `Episodes`.
- **Chức năng Web (BE + FE):** Registration, Login (phân quyền User/Creator), Creator Profile, Create Podcast Channel, Episode Management (CRUD), Podcast Discovery, Search Channel & Episode.
- **SQL Queries:**
  - `Q1`: Tìm các Episodes có thời lượng từ 15–30 phút thuộc một Channel cụ thể.
  - `Q7`: Tìm các Users có tài khoản trên 6 tháng nhưng chưa từng Subscribe.
- **Trách nhiệm bổ sung — Schema Owner:** Quản lý phiên bản Schema chính thức (`full_schema.sql`), kiểm tra PK/FK/naming convention và chịu trách nhiệm tích hợp Database (Global ERD & Database Integration).

#### Member 2 — Quân: **Listening & User Interaction** (`feature/listening-interaction`)
- **Database (3 bảng):** `Subscriptions` (ràng buộc `UNIQUE` chống đăng ký trùng), `ListeningHistory` (lưu tiến trình nghe), `Ratings` (`CHECK` 1–5).
- **Chức năng Web (BE + FE):** Subscribe / Unsubscribe, Audio Player, Listening History, Continue Listening, Rate Episode, My Library.
- **SQL Queries:**
  - `Q3`: Thống kê số lượng Subscriber mới theo từng Channel trong tháng.
  - `Q4`: Tìm các Channel có Rating trung bình dưới 3.
  - `Q5`: Danh sách Episode và số lượt nghe (kể cả Episode chưa có lượt nghe).
  - `Q6`: Tìm các Episodes có lượt nghe cao hơn trung bình các Episodes khác cùng Channel.
- **Trách nhiệm bổ sung — Listening Integration:** Đảm bảo liên kết đúng giữa `ListeningHistory` với `Users` & `Episodes`, kiểm tra lưu tiến trình nghe và phối hợp truy xuất dữ liệu từ Content.

#### Member 3 — Quang: **Advertisement & Analytics** (`feature/ads-analytics`)
- **Database (5 bảng + Trigger):** `Advertisements`, `AdContracts`, `AdSlots`, `AdRevenue`, `Donations`.
  - Triển khai **MySQL Trigger** kiểm tra tối đa **3 hợp đồng cho mỗi Episode có thời lượng dưới 20 phút**.
  - Làm rõ quan hệ giữa `AdContracts` (thỏa thuận thương mại) và `AdSlots` (vị trí quảng cáo trong Episode).
- **Chức năng Web (BE + FE):** Advertisement Management, Ad Contract Management, Ad Slot Management, Revenue Report, Donation History, Monthly Analytics, Top Podcast Report.
- **SQL Queries:**
  - `Q2`: Tìm các quảng cáo xuất hiện trong `EP99`.
  - `Q8`: Tính doanh thu quảng cáo tích lũy theo Creator qua từng tháng bằng **Window Function** (OVER / PARTITION BY).
- **Trách nhiệm bổ sung — Integration Coordinator:** Phụ trách System Architecture, theo dõi tiến độ tích hợp 3 module và điều phối Integration Testing.

---

## 5. Hướng dẫn cài đặt & chạy cục bộ (Quick Start)

1. **Clone repository và chuyển sang nhánh làm việc:**
   ```bash
   git clone https://github.com/manh-dev-AI/Podify.git
   cd Podify
   ```
2. **Cấu hình biến môi trường:**
   ```bash
   cp .env.example .env
   # Mở file .env và điền thông tin kết nối MySQL cục bộ của bạn
   ```
3. **Khởi tạo cơ sở dữ liệu trên MySQL:**
   - Mở **MySQL Workbench** (hoặc MySQL CLI).
   - Chạy `database/schema/full_schema.sql` để tạo database và 12 bảng.
   - Chạy các Trigger trong `database/triggers/` và dữ liệu mẫu `database/seed/full_seed.sql`.
4. **Cài đặt thư viện & chạy Backend (Flask):**
   ```bash
   cd backend
   python -m venv venv
   # Windows: venv\Scripts\activate | macOS/Linux: source venv/bin/activate
   pip install -r requirements.txt
   python app.py
   ```
5. **Mở Frontend:** Mở `frontend/index.html` (qua Live Server của VS Code hoặc cấu hình serve tĩnh từ Flask) để tương tác với hệ thống.
