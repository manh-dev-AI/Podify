-- ===================================================================
-- Seed Data: Module 01 Content Management
-- Owner: Member 1 - Mạnh
-- DBMS: Microsoft SQL Server (T-SQL)
-- ===================================================================

USE podify_db;
GO

-- 1. Insert Users mẫu
-- Cố tình tạo user_1 và user_2 từ 8-10 tháng trước để phục vụ test Q7
INSERT INTO dbo.Users (username, email, password_hash, full_name, role, created_at)
VALUES 
('nguyenvan_a', 'a@example.com', 'hash_pass_123', N'Nguyễn Văn A', 'creator', DATEADD(MONTH, -10, GETDATE())),
('tranthi_b', 'b@example.com', 'hash_pass_123', N'Trần Thị B', 'creator', DATEADD(MONTH, -8, GETDATE())),
('le_c', 'c@example.com', 'hash_pass_123', N'Lê Văn C', 'user', DATEADD(MONTH, -7, GETDATE())), -- User > 6 tháng, chưa subscribe (Dành cho Q7)
('pham_d', 'd@example.com', 'hash_pass_123', N'Phạm Minh D', 'user', DATEADD(MONTH, -2, GETDATE())), -- User mới < 6 tháng
('hoang_e', 'e@example.com', 'hash_pass_123', N'Hoàng Lan E', 'user', GETDATE());
GO

-- 2. Insert Creators mẫu
INSERT INTO dbo.Creators (user_id, display_name, bio, verified)
VALUES 
(1, N'Tech Talk VN', N'Kênh chia sẻ kiến thức công nghệ và lập trình phần mềm.', 1),
(2, N'Góc Tâm Sự', N'Những câu chuyện chữa lành và cuộc sống thường nhật.', 1);
GO

-- 3. Insert PodcastChannels mẫu
INSERT INTO dbo.PodcastChannels (creator_id, title, description, category)
VALUES 
(1, N'Lập Trình Không Khó', N'Học lập trình từ con số 0 cùng các chuyên gia hàng đầu.', N'Công nghệ'),
(1, N'AI & Tương Lai', N'Khám phá thế giới trí tuệ nhân tạo và ứng dụng thực tiễn.', N'Công nghệ'),
(2, N'Trà Chiều Radio', N'Những câu chuyện lắng đọng mỗi buổi chiều cuối tuần.', N'Đời sống');
GO

-- 4. Insert Episodes mẫu
-- Cố tình tạo tập thời lượng 15-30p (900s - 1800s) cho Channel 1 để test Q1
-- Cố tình tạo tập EP99 cho Quang test Q2
INSERT INTO dbo.Episodes (channel_id, title, description, audio_url, duration_seconds, status, published_at)
VALUES 
-- Channel 1:
(1, N'Tập 1: Nhập môn Database và SQL Server', N'Tổng quan về cơ sở dữ liệu quan hệ và cách thiết kế bảng.', '/assets/audio/sample_1.mp3', 1200, 'published', DATEADD(DAY, -20, GETDATE())), -- 20 phút (Thỏa mãn Q1)
(1, N'Tập 2: Chuẩn hóa 3NF trong thực tế', N'Các bước đưa một lược đồ quan hệ về dạng chuẩn 3NF.', '/assets/audio/sample_2.mp3', 1500, 'published', DATEADD(DAY, -15, GETDATE())), -- 25 phút (Thỏa mãn Q1)
(1, N'Tập 3: Viết câu lệnh SELECT nâng cao', N'Hướng dẫn sử dụng JOIN, GROUP BY và Subquery.', '/assets/audio/sample_3.mp3', 600, 'published', DATEADD(DAY, -10, GETDATE())),  -- 10 phút (< 15p, không lọt vào Q1)
(1, N'Tập 4: Tối ưu chỉ mục Indexes', N'Cách Index tăng tốc độ truy vấn trong cơ sở dữ liệu lớn.', '/assets/audio/sample_4.mp3', 2400, 'published', DATEADD(DAY, -5, GETDATE())),  -- 40 phút (> 30p, không lọt vào Q1)

-- Channel 2:
(2, N'EP99 - Xu hướng AI năm 2026', N'Tập đặc biệt bàn về tương lai công nghệ AI.', '/assets/audio/sample_ep99.mp3', 1800, 'published', DATEADD(DAY, -8, GETDATE())), -- Dành cho câu Q2 của Quang

-- Channel 3:
(3, N'Bình yên nơi góc phố', N'Những giai điệu và lời tự sự nhẹ nhàng.', '/assets/audio/sample_5.mp3', 950, 'published', DATEADD(DAY, -3, GETDATE())); -- 15.8 phút (Channel 3)
GO
