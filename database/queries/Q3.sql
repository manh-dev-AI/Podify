-- ===================================================================
-- Query Q3: Thống kê số lượng Subscriber mới theo từng Channel trong tháng
-- Owner: Member 2 - Quân
-- DBMS: MySQL 8.0
-- SQL Concepts: LEFT JOIN (điều kiện tháng đặt ở ON), COUNT, GROUP BY, Date Functions
-- ===================================================================

USE podify_db;

SET @target_year = YEAR(CURDATE());
SET @target_month = MONTH(CURDATE());

SELECT
    c.channel_id,
    c.title AS channel_title,
    c.category,
    MAX(CONCAT(@target_year, '-', LPAD(@target_month, 2, '0'))) AS report_month,
    COUNT(s.subscription_id) AS new_subscribers_count
FROM PodcastChannels c
LEFT JOIN Subscriptions s
    ON c.channel_id = s.channel_id
   AND YEAR(s.subscribed_at) = @target_year
   AND MONTH(s.subscribed_at) = @target_month
GROUP BY c.channel_id, c.title, c.category
ORDER BY new_subscribers_count DESC, c.channel_id ASC;
