-- ===================================================================
-- Seed Data: Module 01 Content Management
-- Owner: Member 1 - Mạnh
-- DBMS: MySQL 8.0
-- Ghi chú: Mật khẩu mẫu cho tất cả tài khoản demo là: 123456
-- ===================================================================

USE podify_db;

-- 1. Insert Users mẫu
-- Cố tình tạo user 1, 2, 3 từ 7-10 tháng trước; trong đó user 3 (le_c) chưa từng subscribe (test Q7)
INSERT INTO Users (username, email, password_hash, full_name, role, created_at)
VALUES
('nguyenvan_a', 'a@example.com', 'pbkdf2:sha256:1000000$YKnNiqznvHlaJuBm$53b3b308e36c5f85ee17865fe77abe46e8170ad6671d4d77c65ed59727d81895', 'Nguyễn Văn A', 'creator', DATE_SUB(NOW(), INTERVAL 10 MONTH)),
('tranthi_b',   'b@example.com', 'pbkdf2:sha256:1000000$YKnNiqznvHlaJuBm$53b3b308e36c5f85ee17865fe77abe46e8170ad6671d4d77c65ed59727d81895', 'Trần Thị B',   'creator', DATE_SUB(NOW(), INTERVAL 8 MONTH)),
('le_c',        'c@example.com', 'pbkdf2:sha256:1000000$YKnNiqznvHlaJuBm$53b3b308e36c5f85ee17865fe77abe46e8170ad6671d4d77c65ed59727d81895', 'Lê Văn C',     'user',    DATE_SUB(NOW(), INTERVAL 7 MONTH)),
('pham_d',      'd@example.com', 'pbkdf2:sha256:1000000$YKnNiqznvHlaJuBm$53b3b308e36c5f85ee17865fe77abe46e8170ad6671d4d77c65ed59727d81895', 'Phạm Minh D',  'user',    DATE_SUB(NOW(), INTERVAL 2 MONTH)),
('hoang_e',     'e@example.com', 'pbkdf2:sha256:1000000$YKnNiqznvHlaJuBm$53b3b308e36c5f85ee17865fe77abe46e8170ad6671d4d77c65ed59727d81895', 'Hoàng Lan E',  'user',    NOW()),
('minh_f',      'f@example.com', 'pbkdf2:sha256:1000000$YKnNiqznvHlaJuBm$53b3b308e36c5f85ee17865fe77abe46e8170ad6671d4d77c65ed59727d81895', 'Trần Minh F',  'user',    DATE_SUB(NOW(), INTERVAL 3 MONTH));

-- 2. Insert Creators mẫu
INSERT INTO Creators (user_id, display_name, bio, verified)
VALUES
(1, 'Tech Talk VN', 'Kênh chia sẻ kiến thức công nghệ, cơ sở dữ liệu và lập trình phần mềm.', TRUE),
(2, 'Góc Tâm Sự', 'Những câu chuyện chữa lành, kỹ năng sống và cuộc sống thường nhật.', TRUE);

-- 3. Insert PodcastChannels mẫu
INSERT INTO PodcastChannels (creator_id, title, description, category)
VALUES
(1, 'Lập Trình Không Khó', 'Học lập trình và thiết kế cơ sở dữ liệu từ con số 0 cùng chuyên gia.', 'Công nghệ'),
(1, 'AI & Tương Lai', 'Khám phá thế giới trí tuệ nhân tạo và ứng dụng thực tiễn.', 'Công nghệ'),
(2, 'Trà Chiều Radio', 'Những câu chuyện lắng đọng mỗi buổi chiều cuối tuần.', 'Đời sống');

-- 4. Insert Episodes mẫu
-- Ep 1, 2: 15-30 phút thuộc Channel 1 -> Khớp Q1
-- Ep 3: 10 phút (< 20 phút) -> Dùng test Trigger tối đa 3 hợp đồng quảng cáo
-- Ep 4: 40 phút (>= 20 phút) -> Có thể gắn > 3 hợp đồng; đồng thời để 0 lượt nghe test Q5
-- Ep 5: EP99 -> Phục vụ Q2 (quảng cáo xuất hiện trong EP99)
INSERT INTO Episodes (channel_id, title, description, audio_url, duration_seconds, status, published_at)
VALUES
(1, 'Tập 1: Nhập môn Database và MySQL', 'Tổng quan về cơ sở dữ liệu quan hệ và cách thiết kế bảng.', '/assets/audio/sample_1.mp3', 1200, 'published', DATE_SUB(NOW(), INTERVAL 20 DAY)),
(1, 'Tập 2: Chuẩn hóa 3NF trong thực tế', 'Các bước đưa một lược đồ quan hệ về dạng chuẩn 3NF.', '/assets/audio/sample_2.mp3', 1500, 'published', DATE_SUB(NOW(), INTERVAL 15 DAY)),
(1, 'Tập 3: Viết câu lệnh SELECT nâng cao', 'Hướng dẫn sử dụng JOIN, GROUP BY và Subquery.', '/assets/audio/sample_3.mp3', 600, 'published', DATE_SUB(NOW(), INTERVAL 10 DAY)),
(1, 'Tập 4: Tối ưu chỉ mục Indexes', 'Cách Index tăng tốc độ truy vấn trong cơ sở dữ liệu lớn.', '/assets/audio/sample_4.mp3', 2400, 'published', DATE_SUB(NOW(), INTERVAL 5 DAY)),
(2, 'EP99 - Xu hướng AI năm 2026', 'Tập đặc biệt bàn về tương lai công nghệ AI và Agent.', '/assets/audio/sample_ep99.mp3', 1800, 'published', DATE_SUB(NOW(), INTERVAL 8 DAY)),
(3, 'Bình yên nơi góc phố', 'Những giai điệu nhẹ nhàng thư giãn — Bản nhạc Dựa Vai Anh.', '/assets/audio/nhac_dua_vai_anh.mp3', 950, 'published', DATE_SUB(NOW(), INTERVAL 3 DAY)),
(2, 'EP98 - LLM và RAG thực chiến', 'Kiến trúc truy xuất tăng cường và triển khai hệ thống AI doanh nghiệp.', '/assets/audio/sample_6.mp3', 1320, 'published', DATE_SUB(NOW(), INTERVAL 14 DAY)),
(3, 'Đêm mưa nghe lại chuyện cũ', 'Giai điệu cảm xúc về tình cảm gia đình — Bản nhạc Ước Mơ Của Mẹ.', '/assets/audio/nhac_uoc_mo_cua_me.mp3', 1100, 'published', DATE_SUB(NOW(), INTERVAL 9 DAY)),
(3, 'Sống chậm lại giữa dòng đời vội vã', 'Podcast tâm sự về cuộc sống, cân bằng áp lực và tìm lại sự bình an trong tâm hồn.', '/assets/audio/podcast_cuoc_song.mp3', 960, 'published', DATE_SUB(NOW(), INTERVAL 2 DAY)),
(3, 'Tình yêu trưởng thành: Bình yên là khi hiểu nhau', 'Podcast chia sẻ về tình yêu, sự lắng nghe và đồng hành bền lâu qua năm tháng.', '/assets/audio/podcast_tinh_yeu.mp3', 1080, 'published', DATE_SUB(NOW(), INTERVAL 1 DAY)),
(3, 'Hoài bão tuổi trẻ: Dám mơ lớn và kiên trì bước tiếp', 'Podcast truyền cảm hứng về ước mơ, hoài bão con người và bản lĩnh vượt qua thử thách.', '/assets/audio/podcast_hoai_bao.mp3', 1260, 'published', NOW());
