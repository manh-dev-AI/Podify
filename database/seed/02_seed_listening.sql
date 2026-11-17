-- ===================================================================
-- Seed Data: Module 02 Listening & Interaction
-- Owner: Member 2 - Quân
-- DBMS: MySQL 8.0
-- Tables: Subscriptions, ListeningHistory, Ratings
-- Lưu ý: User 3 (le_c) CỐ TÌNH KHÔNG có trong Subscriptions để test Q7.
-- ===================================================================

USE podify_db;

-- 1. Subscriptions
-- Có cả lượt đăng ký trong tháng hiện tại (test Q3) và tháng trước (để kiểm chứng lọc theo tháng)
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

-- 2. ListeningHistory
-- Ep 1: 5 lượt | Ep 2: 3 lượt | Ep 3: 1 lượt | Ep 4: 0 lượt (test LEFT JOIN Q5)
-- Ep 5 (EP99): 4 lượt | Ep 7: 1 lượt
-- Ep 6: 2 lượt | Ep 8: 1 lượt
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

-- 3. Ratings
-- Channel 1: TB 4.60 | Channel 2: TB 4.67 | Channel 3: TB 2.33 (< 3 -> khớp Q4!)
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
