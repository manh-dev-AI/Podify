-- ===================================================================
-- Podify Official Complete Seed Script (MySQL 8.0 - All 12 Tables)
-- Run order: Execute full_schema.sql + triggers/01_ad_contract_limit.sql FIRST
-- ===================================================================

USE podify_db;

-- Làm sạch dữ liệu cũ và reset AUTO_INCREMENT trước khi nạp mẫu
SET FOREIGN_KEY_CHECKS = 0;
TRUNCATE TABLE Donations;
TRUNCATE TABLE AdRevenue;
TRUNCATE TABLE AdSlots;
TRUNCATE TABLE AdContracts;
TRUNCATE TABLE Advertisements;
TRUNCATE TABLE Ratings;
TRUNCATE TABLE ListeningHistory;
TRUNCATE TABLE Subscriptions;
TRUNCATE TABLE Episodes;
TRUNCATE TABLE PodcastChannels;
TRUNCATE TABLE Creators;
TRUNCATE TABLE Users;
SET FOREIGN_KEY_CHECKS = 1;

-- ===================================================================
-- 1. MODULE 01: CONTENT MANAGEMENT
-- ===================================================================

INSERT INTO Users (username, email, password_hash, full_name, role, created_at)
VALUES
('nguyenvan_a', 'a@example.com', 'pbkdf2:sha256:1000000$YKnNiqznvHlaJuBm$53b3b308e36c5f85ee17865fe77abe46e8170ad6671d4d77c65ed59727d81895', 'Nguyễn Văn A', 'creator', DATE_SUB(NOW(), INTERVAL 10 MONTH)),
('tranthi_b',   'b@example.com', 'pbkdf2:sha256:1000000$YKnNiqznvHlaJuBm$53b3b308e36c5f85ee17865fe77abe46e8170ad6671d4d77c65ed59727d81895', 'Trần Thị B',   'creator', DATE_SUB(NOW(), INTERVAL 8 MONTH)),
('le_c',        'c@example.com', 'pbkdf2:sha256:1000000$YKnNiqznvHlaJuBm$53b3b308e36c5f85ee17865fe77abe46e8170ad6671d4d77c65ed59727d81895', 'Lê Văn C',     'user',    DATE_SUB(NOW(), INTERVAL 7 MONTH)),
('pham_d',      'd@example.com', 'pbkdf2:sha256:1000000$YKnNiqznvHlaJuBm$53b3b308e36c5f85ee17865fe77abe46e8170ad6671d4d77c65ed59727d81895', 'Phạm Minh D',  'user',    DATE_SUB(NOW(), INTERVAL 2 MONTH)),
('hoang_e',     'e@example.com', 'pbkdf2:sha256:1000000$YKnNiqznvHlaJuBm$53b3b308e36c5f85ee17865fe77abe46e8170ad6671d4d77c65ed59727d81895', 'Hoàng Lan E',  'user',    NOW()),
('minh_f',      'f@example.com', 'pbkdf2:sha256:1000000$YKnNiqznvHlaJuBm$53b3b308e36c5f85ee17865fe77abe46e8170ad6671d4d77c65ed59727d81895', 'Trần Minh F',  'user',    DATE_SUB(NOW(), INTERVAL 3 MONTH));

INSERT INTO Creators (user_id, display_name, bio, verified)
VALUES
(1, 'Tech Talk VN', 'Kênh chia sẻ kiến thức công nghệ, cơ sở dữ liệu và lập trình phần mềm.', TRUE),
(2, 'Góc Tâm Sự', 'Những câu chuyện chữa lành, kỹ năng sống và cuộc sống thường nhật.', TRUE);

INSERT INTO PodcastChannels (creator_id, title, description, category)
VALUES
(1, 'Lập Trình Không Khó', 'Học lập trình và thiết kế cơ sở dữ liệu từ con số 0 cùng chuyên gia.', 'Công nghệ'),
(1, 'AI & Tương Lai', 'Khám phá thế giới trí tuệ nhân tạo và ứng dụng thực tiễn.', 'Công nghệ'),
(2, 'Trà Chiều Radio', 'Những câu chuyện lắng đọng mỗi buổi chiều cuối tuần.', 'Đời sống');

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

-- ===================================================================
-- 2. MODULE 02: LISTENING & USER INTERACTION
-- ===================================================================

INSERT INTO Subscriptions (user_id, channel_id, subscribed_at, notify_enabled)
VALUES
(2, 1, DATE_FORMAT(NOW(), '%Y-%m-01 09:00:00'), TRUE),
(4, 1, NOW(), TRUE),
(6, 1, NOW(), TRUE),
(5, 1, DATE_SUB(DATE_FORMAT(NOW(), '%Y-%m-01 10:00:00'), INTERVAL 1 MONTH), TRUE),
(4, 2, DATE_FORMAT(NOW(), '%Y-%m-01 10:30:00'), TRUE),
(6, 2, DATE_SUB(DATE_FORMAT(NOW(), '%Y-%m-01 14:00:00'), INTERVAL 2 MONTH), FALSE),
(1, 3, DATE_SUB(DATE_FORMAT(NOW(), '%Y-%m-01 11:00:00'), INTERVAL 1 MONTH), TRUE),
(5, 3, NOW(), TRUE);

INSERT INTO ListeningHistory (user_id, episode_id, last_position_seconds, is_completed, listened_at)
VALUES
(2, 1, 1200, TRUE,  DATE_SUB(NOW(), INTERVAL 12 DAY)),
(4, 1, 1200, TRUE,  DATE_SUB(NOW(), INTERVAL 10 DAY)),
(5, 1, 780,  FALSE, DATE_SUB(NOW(), INTERVAL 4 DAY)),
(6, 1, 1200, TRUE,  DATE_SUB(NOW(), INTERVAL 3 DAY)),
(4, 1, 320,  FALSE, DATE_SUB(NOW(), INTERVAL 2 HOUR)),
(4, 2, 1500, TRUE,  DATE_SUB(NOW(), INTERVAL 9 DAY)),
(5, 2, 600,  FALSE, DATE_SUB(NOW(), INTERVAL 2 DAY)),
(6, 2, 1500, TRUE,  DATE_SUB(NOW(), INTERVAL 1 DAY)),
(4, 3, 420,  FALSE, DATE_SUB(NOW(), INTERVAL 6 HOUR)),
(2, 5, 1800, TRUE,  DATE_SUB(NOW(), INTERVAL 7 DAY)),
(4, 5, 950,  FALSE, DATE_SUB(NOW(), INTERVAL 1 DAY)),
(5, 5, 1800, TRUE,  DATE_SUB(NOW(), INTERVAL 3 DAY)),
(6, 5, 1200, FALSE, DATE_SUB(NOW(), INTERVAL 5 HOUR)),
(4, 7, 500,  FALSE, DATE_SUB(NOW(), INTERVAL 12 HOUR)),
(1, 6, 950,  TRUE,  DATE_SUB(NOW(), INTERVAL 2 DAY)),
(4, 6, 400,  FALSE, DATE_SUB(NOW(), INTERVAL 8 HOUR)),
(5, 8, 300,  FALSE, DATE_SUB(NOW(), INTERVAL 1 DAY));

INSERT INTO Ratings (user_id, episode_id, score, comment)
VALUES
(2, 1, 5, 'Giải thích rất trực quan, dễ hiểu cho người mới.'),
(4, 1, 5, 'Nội dung Database cơ bản nhưng cực kỳ chắc.'),
(6, 1, 4, 'Âm thanh rõ ràng, ví dụ thực tế.'),
(4, 2, 5, 'Phần 3NF rất hữu ích khi làm đồ án.'),
(5, 2, 4, 'Rất đáng nghe.'),
(2, 5, 5, 'Tập EP99 phân tích xu hướng AI cực chất lượng!'),
(4, 5, 5, 'Rất nhiều góc nhìn mới về AI Agents.'),
(5, 5, 4, 'Hay và cô đọng.'),
(1, 6, 2, 'Âm lượng nhạc nền hơi lớn so với giọng đọc.'),
(4, 6, 2, 'Nhịp độ hơi chậm so với kỳ vọng.'),
(5, 8, 3, 'Nội dung ổn nhưng thu âm chưa đều.');

-- ===================================================================
-- 3. MODULE 03: ADVERTISEMENT & ANALYTICS
-- ===================================================================

INSERT INTO Advertisements (advertiser_name, title, description, target_url, duration_seconds, status)
VALUES
('FPT Cloud', 'FPT Cloud - Hạ tầng Cloud thuần Việt', 'Tặng voucher 5 triệu cho lập trình viên đăng ký mới.', 'https://fptcloud.com', 30, 'active'),
('TopCV', 'TopCV - Việc làm IT chất lượng cao', 'Kết nối hơn 50.000 cơ hội việc làm công nghệ.', 'https://topcv.vn', 25, 'active'),
('Shopee Tech', 'Shopee Tech - Siêu hội phụ kiện', 'Giảm đến 40% bàn phím cơ và micro thu âm.', 'https://shopee.vn', 20, 'active'),
('Vietcombank', 'VCB Digibank - Thanh toán không chạm', 'Hoàn tiền 10% khi thanh toán hóa đơn dịch vụ số.', 'https://vietcombank.com.vn', 30, 'active'),
('ELSA Speak', 'ELSA Speak - Luyện phát âm AI', 'Giảm 50% gói học tiếng Anh giao tiếp trọn đời.', 'https://elsaspeak.com', 20, 'active');

INSERT INTO AdContracts (ad_id, creator_id, contract_code, contract_value, cpm_rate, start_date, end_date, status)
VALUES
(1, 1, 'CTR-2026-001', 15000000.00, 120000.00, DATE_SUB(CURDATE(), INTERVAL 4 MONTH), DATE_ADD(CURDATE(), INTERVAL 2 MONTH), 'active'),
(2, 1, 'CTR-2026-002', 12000000.00, 100000.00, DATE_SUB(CURDATE(), INTERVAL 4 MONTH), DATE_ADD(CURDATE(), INTERVAL 2 MONTH), 'active'),
(3, 1, 'CTR-2026-003',  8000000.00,  85000.00, DATE_SUB(CURDATE(), INTERVAL 3 MONTH), DATE_ADD(CURDATE(), INTERVAL 3 MONTH), 'active'),
(4, 1, 'CTR-2026-004', 18000000.00, 150000.00, DATE_SUB(CURDATE(), INTERVAL 2 MONTH), DATE_ADD(CURDATE(), INTERVAL 4 MONTH), 'active'),
(5, 2, 'CTR-2026-005',  9000000.00,  95000.00, DATE_SUB(CURDATE(), INTERVAL 3 MONTH), DATE_ADD(CURDATE(), INTERVAL 3 MONTH), 'active');

INSERT INTO AdSlots (contract_id, episode_id, slot_position, start_offset_seconds, status)
VALUES
(1, 5, 'pre-roll',   0,    'active'),
(2, 5, 'mid-roll',   900,  'active'),
(4, 5, 'post-roll',  1740, 'active'),
(1, 3, 'pre-roll',   0,    'active'),
(2, 3, 'mid-roll',   300,  'active'),
(3, 3, 'post-roll',  560,  'active'),
(1, 4, 'pre-roll',   0,    'active'),
(2, 4, 'mid-roll',   800,  'active'),
(3, 4, 'mid-roll',   1600, 'active'),
(4, 4, 'post-roll',  2350, 'active'),
(5, 6, 'pre-roll',   0,    'active');

INSERT INTO AdRevenue (contract_id, slot_id, revenue_date, impressions, amount, notes)
VALUES
(1, 1, DATE_ADD(DATE_SUB(DATE_FORMAT(CURDATE(), '%Y-%m-01'), INTERVAL 3 MONTH), INTERVAL 14 DAY), 29100, 3500000.00, 'Doanh thu FPT Cloud tháng T-3'),
(2, 2, DATE_ADD(DATE_SUB(DATE_FORMAT(CURDATE(), '%Y-%m-01'), INTERVAL 3 MONTH), INTERVAL 18 DAY), 25000, 2500000.00, 'Doanh thu TopCV tháng T-3'),
(1, 1, DATE_ADD(DATE_SUB(DATE_FORMAT(CURDATE(), '%Y-%m-01'), INTERVAL 2 MONTH), INTERVAL 14 DAY), 35000, 4200000.00, 'Doanh thu FPT Cloud tháng T-2'),
(3, 6, DATE_ADD(DATE_SUB(DATE_FORMAT(CURDATE(), '%Y-%m-01'), INTERVAL 2 MONTH), INTERVAL 20 DAY), 32900, 2800000.00, 'Doanh thu Shopee Tech tháng T-2'),
(2, 2, DATE_ADD(DATE_SUB(DATE_FORMAT(CURDATE(), '%Y-%m-01'), INTERVAL 1 MONTH), INTERVAL 12 DAY), 38000, 3800000.00, 'Doanh thu TopCV tháng T-1'),
(4, 3, DATE_ADD(DATE_SUB(DATE_FORMAT(CURDATE(), '%Y-%m-01'), INTERVAL 1 MONTH), INTERVAL 19 DAY), 34600, 5200000.00, 'Doanh thu Vietcombank tháng T-1'),
(1, 1, DATE_FORMAT(CURDATE(), '%Y-%m-01'), 37500, 4500000.00, 'Doanh thu FPT Cloud đầu tháng hiện tại'),
(4, 3, DATE_FORMAT(CURDATE(), '%Y-%m-02'), 40000, 6000000.00, 'Doanh thu Vietcombank đầu tháng hiện tại'),
(5, 11, DATE_ADD(DATE_SUB(DATE_FORMAT(CURDATE(), '%Y-%m-01'), INTERVAL 2 MONTH), INTERVAL 16 DAY), 21000, 2000000.00, 'Doanh thu ELSA Speak tháng T-2'),
(5, 11, DATE_ADD(DATE_SUB(DATE_FORMAT(CURDATE(), '%Y-%m-01'), INTERVAL 1 MONTH), INTERVAL 16 DAY), 26300, 2500000.00, 'Doanh thu ELSA Speak tháng T-1'),
(5, 11, DATE_FORMAT(CURDATE(), '%Y-%m-01'), 31500, 3000000.00, 'Doanh thu ELSA Speak tháng hiện tại');

INSERT INTO Donations (donor_user_id, creator_id, episode_id, amount, message, donated_at)
VALUES
(4, 1, 1,    100000.00, 'Cảm ơn anh chia sẻ kiến thức SQL rất dễ hiểu!', DATE_SUB(NOW(), INTERVAL 6 DAY)),
(5, 1, 5,    200000.00, 'Tập EP99 phân tích AI rất chất lượng!', DATE_SUB(NOW(), INTERVAL 3 DAY)),
(6, 2, 6,     50000.00, 'Nghe rất thư giãn mỗi buổi chiều.', DATE_SUB(NOW(), INTERVAL 2 DAY)),
(4, 2, NULL, 150000.00, 'Ủng hộ kênh Trà Chiều Radio ra thêm tập mới!', DATE_SUB(NOW(), INTERVAL 1 DAY));
