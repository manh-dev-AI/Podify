-- ===================================================================
-- Seed Data: Module 01 Content Management
-- Owner: Member 1 - Mạnh
-- DBMS: MySQL
-- ===================================================================

USE podify_db;

-- 1. Insert Users mẫu
-- Cố tình tạo user 1 và 2 từ 8-10 tháng trước để phục vụ test Q7
INSERT INTO Users (username, email, password_hash, full_name, role, created_at)
VALUES 
('nguyenvan_a', 'a@example.com', 'hash_pass_123', 'Nguyễn Văn A', 'creator', DATE_SUB(NOW(), INTERVAL 10 MONTH)),
('tranthi_b', 'b@example.com', 'hash_pass_123', 'Trần Thị B', 'creator', DATE_SUB(NOW(), INTERVAL 8 MONTH)),
('le_c', 'c@example.com', 'hash_pass_123', 'Lê Văn C', 'user', DATE_SUB(NOW(), INTERVAL 7 MONTH)), -- User > 6 tháng, chưa subscribe (Dành cho Q7)
('pham_d', 'd@example.com', 'hash_pass_123', 'Phạm Minh D', 'user', DATE_SUB(NOW(), INTERVAL 2 MONTH)), -- User mới < 6 tháng
('hoang_e', 'e@example.com', 'hash_pass_123', 'Hoàng Lan E', 'user', NOW());

-- 2. Insert Creators mẫu
INSERT INTO Creators (user_id, display_name, bio, verified)
VALUES 
(1, 'Tech Talk VN', 'Kênh chia sẻ kiến thức công nghệ và lập trình phần mềm.', TRUE),
(2, 'Góc Tâm Sự', 'Những câu chuyện chữa lành và cuộc sống thường nhật.', TRUE);

-- 3. Insert PodcastChannels mẫu
INSERT INTO PodcastChannels (creator_id, title, description, category)
VALUES 
(1, 'Lập Trình Không Khó', 'Học lập trình từ con số 0 cùng các chuyên gia hàng đầu.', 'Công nghệ'),
(1, 'AI & Tương Lai', 'Khám phá thế giới trí tuệ nhân tạo và ứng dụng thực tiễn.', 'Công nghệ'),
(2, 'Trà Chiều Radio', 'Những câu chuyện lắng đọng mỗi buổi chiều cuối tuần.', 'Đời sống');

-- 4. Insert Episodes mẫu
-- Cố tình tạo tập thời lượng 15-30p (900s - 1800s) cho Channel 1 để test Q1
-- Cố tình tạo tập EP99 cho Quang test Q2
INSERT INTO Episodes (channel_id, title, description, audio_url, duration_seconds, status, published_at)
VALUES 
-- Channel 1:
(1, 'Tập 1: Nhập môn Database và MySQL', 'Tổng quan về cơ sở dữ liệu quan hệ và cách thiết kế bảng.', '/assets/audio/sample_1.mp3', 1200, 'published', DATE_SUB(NOW(), INTERVAL 20 DAY)), -- 20 phút (Thỏa mãn Q1)
(1, 'Tập 2: Chuẩn hóa 3NF trong thực tế', 'Các bước đưa một lược đồ quan hệ về dạng chuẩn 3NF.', '/assets/audio/sample_2.mp3', 1500, 'published', DATE_SUB(NOW(), INTERVAL 15 DAY)), -- 25 phút (Thỏa mãn Q1)
(1, 'Tập 3: Viết câu lệnh SELECT nâng cao', 'Hướng dẫn sử dụng JOIN, GROUP BY và Subquery.', '/assets/audio/sample_3.mp3', 600, 'published', DATE_SUB(NOW(), INTERVAL 10 DAY)),  -- 10 phút (< 15p, không lọt vào Q1)
(1, 'Tập 4: Tối ưu chỉ mục Indexes', 'Cách Index tăng tốc độ truy vấn trong cơ sở dữ liệu lớn.', '/assets/audio/sample_4.mp3', 2400, 'published', DATE_SUB(NOW(), INTERVAL 5 DAY)),  -- 40 phút (> 30p, không lọt vào Q1)

-- Channel 2:
(2, 'EP99 - Xu hướng AI năm 2026', 'Tập đặc biệt bàn về tương lai công nghệ AI.', '/assets/audio/sample_ep99.mp3', 1800, 'published', DATE_SUB(NOW(), INTERVAL 8 DAY)), -- Dành cho câu Q2 của Quang

-- Channel 3:
(3, 'Bình yên nơi góc phố', 'Những giai điệu và lời tự sự nhẹ nhàng.', '/assets/audio/sample_5.mp3', 950, 'published', DATE_SUB(NOW(), INTERVAL 3 DAY)); -- 15.8 phút (Channel 3)
