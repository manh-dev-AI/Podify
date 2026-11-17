-- ===================================================================
-- Seed Data: Module 03 Advertisement & Analytics
-- Owner: Member 3 - Quang
-- DBMS: MySQL 8.0
-- Tables: Advertisements, AdContracts, AdSlots, AdRevenue, Donations
-- ===================================================================

USE podify_db;

-- 1. Advertisements (5 chiến dịch quảng cáo mẫu)
INSERT INTO Advertisements (advertiser_name, title, description, target_url, duration_seconds, status)
VALUES
('FPT Cloud', 'FPT Cloud - Hạ tầng Cloud thuần Việt', 'Tặng voucher 5 triệu cho lập trình viên đăng ký mới.', 'https://fptcloud.com', 30, 'active'),
('TopCV', 'TopCV - Việc làm IT chất lượng cao', 'Kết nối hơn 50.000 cơ hội việc làm công nghệ.', 'https://topcv.vn', 25, 'active'),
('Shopee Tech', 'Shopee Tech - Siêu hội phụ kiện', 'Giảm đến 40% bàn phím cơ và micro thu âm.', 'https://shopee.vn', 20, 'active'),
('Vietcombank', 'VCB Digibank - Thanh toán không chạm', 'Hoàn tiền 10% khi thanh toán hóa đơn dịch vụ số.', 'https://vietcombank.com.vn', 30, 'active'),
('ELSA Speak', 'ELSA Speak - Luyện phát âm AI', 'Giảm 50% gói học tiếng Anh giao tiếp trọn đời.', 'https://elsaspeak.com', 20, 'active');

-- 2. AdContracts (Hợp đồng 1..4 của Creator 1, Hợp đồng 5 của Creator 2)
INSERT INTO AdContracts (ad_id, creator_id, contract_code, contract_value, cpm_rate, start_date, end_date, status)
VALUES
(1, 1, 'CTR-2026-001', 15000000.00, 120000.00, DATE_SUB(CURDATE(), INTERVAL 4 MONTH), DATE_ADD(CURDATE(), INTERVAL 2 MONTH), 'active'),
(2, 1, 'CTR-2026-002', 12000000.00, 100000.00, DATE_SUB(CURDATE(), INTERVAL 4 MONTH), DATE_ADD(CURDATE(), INTERVAL 2 MONTH), 'active'),
(3, 1, 'CTR-2026-003',  8000000.00,  85000.00, DATE_SUB(CURDATE(), INTERVAL 3 MONTH), DATE_ADD(CURDATE(), INTERVAL 3 MONTH), 'active'),
(4, 1, 'CTR-2026-004', 18000000.00, 150000.00, DATE_SUB(CURDATE(), INTERVAL 2 MONTH), DATE_ADD(CURDATE(), INTERVAL 4 MONTH), 'active'),
(5, 2, 'CTR-2026-005',  9000000.00,  95000.00, DATE_SUB(CURDATE(), INTERVAL 3 MONTH), DATE_ADD(CURDATE(), INTERVAL 3 MONTH), 'active');

-- 3. AdSlots
-- Ep 5 (EP99, 1800s): 3 quảng cáo -> phục vụ Q2
-- Ep 3 (600s < 20p): ĐÃ GẮN TỐI ĐA 3 hợp đồng (1, 2, 3) -> gán thêm hợp đồng thứ 4 sẽ bị Trigger chặn!
-- Ep 4 (2400s >= 20p): Gắn 4 hợp đồng (1, 2, 3, 4) -> chứng minh >= 20 phút không bị giới hạn 3 hợp đồng!
-- Ep 6 (950s < 20p, Creator 2): Gắn 1 hợp đồng (5)
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

-- 4. AdRevenue (Dữ liệu nhiều tháng liên tiếp phục vụ Q8 Window Function)
INSERT INTO AdRevenue (contract_id, slot_id, revenue_date, impressions, amount, notes)
VALUES
-- Creator 1 - Tháng T-3
(1, 1, DATE_ADD(DATE_SUB(DATE_FORMAT(CURDATE(), '%Y-%m-01'), INTERVAL 3 MONTH), INTERVAL 14 DAY), 29100, 3500000.00, 'Doanh thu FPT Cloud tháng T-3'),
(2, 2, DATE_ADD(DATE_SUB(DATE_FORMAT(CURDATE(), '%Y-%m-01'), INTERVAL 3 MONTH), INTERVAL 18 DAY), 25000, 2500000.00, 'Doanh thu TopCV tháng T-3'),
-- Creator 1 - Tháng T-2
(1, 1, DATE_ADD(DATE_SUB(DATE_FORMAT(CURDATE(), '%Y-%m-01'), INTERVAL 2 MONTH), INTERVAL 14 DAY), 35000, 4200000.00, 'Doanh thu FPT Cloud tháng T-2'),
(3, 6, DATE_ADD(DATE_SUB(DATE_FORMAT(CURDATE(), '%Y-%m-01'), INTERVAL 2 MONTH), INTERVAL 20 DAY), 32900, 2800000.00, 'Doanh thu Shopee Tech tháng T-2'),
-- Creator 1 - Tháng T-1
(2, 2, DATE_ADD(DATE_SUB(DATE_FORMAT(CURDATE(), '%Y-%m-01'), INTERVAL 1 MONTH), INTERVAL 12 DAY), 38000, 3800000.00, 'Doanh thu TopCV tháng T-1'),
(4, 3, DATE_ADD(DATE_SUB(DATE_FORMAT(CURDATE(), '%Y-%m-01'), INTERVAL 1 MONTH), INTERVAL 19 DAY), 34600, 5200000.00, 'Doanh thu Vietcombank tháng T-1'),
-- Creator 1 - Tháng hiện tại
(1, 1, DATE_FORMAT(CURDATE(), '%Y-%m-01'), 37500, 4500000.00, 'Doanh thu FPT Cloud đầu tháng hiện tại'),
(4, 3, DATE_FORMAT(CURDATE(), '%Y-%m-02'), 40000, 6000000.00, 'Doanh thu Vietcombank đầu tháng hiện tại'),

-- Creator 2 - 3 tháng gần nhất
(5, 11, DATE_ADD(DATE_SUB(DATE_FORMAT(CURDATE(), '%Y-%m-01'), INTERVAL 2 MONTH), INTERVAL 16 DAY), 21000, 2000000.00, 'Doanh thu ELSA Speak tháng T-2'),
(5, 11, DATE_ADD(DATE_SUB(DATE_FORMAT(CURDATE(), '%Y-%m-01'), INTERVAL 1 MONTH), INTERVAL 16 DAY), 26300, 2500000.00, 'Doanh thu ELSA Speak tháng T-1'),
(5, 11, DATE_FORMAT(CURDATE(), '%Y-%m-01'), 31500, 3000000.00, 'Doanh thu ELSA Speak tháng hiện tại');

-- 5. Donations
INSERT INTO Donations (donor_user_id, creator_id, episode_id, amount, message, donated_at)
VALUES
(4, 1, 1,    100000.00, 'Cảm ơn anh chia sẻ kiến thức SQL rất dễ hiểu!', DATE_SUB(NOW(), INTERVAL 6 DAY)),
(5, 1, 5,    200000.00, 'Tập EP99 phân tích AI rất chất lượng!', DATE_SUB(NOW(), INTERVAL 3 DAY)),
(6, 2, 6,     50000.00, 'Nghe rất thư giãn mỗi buổi chiều.', DATE_SUB(NOW(), INTERVAL 2 DAY)),
(4, 2, NULL, 150000.00, 'Ủng hộ kênh Trà Chiều Radio ra thêm tập mới!', DATE_SUB(NOW(), INTERVAL 1 DAY));
