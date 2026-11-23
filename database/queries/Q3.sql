-- ===================================================================
-- Query Q3: Thống kê số lượng Subscriber mới theo từng Channel trong tháng
-- Owner: Member 2 - Quân
-- DBMS: MySQL 8.0
-- SQL Concepts: LEFT JOIN (điều kiện tháng đặt ở ON), COUNT, GROUP BY, Date Functions
-- ===================================================================

USE podify_db;

SELECT 
    c.channel_id,
    c.title,
    COUNT(s.subscription_id) AS new_subscribers
FROM PodcastChannels c
LEFT JOIN Subscriptions s 
    ON c.channel_id = s.channel_id
    AND MONTH(s.subscribed_at) = MONTH(CURDATE())
    AND YEAR(s.subscribed_at) = YEAR(CURDATE())
GROUP BY c.channel_id, c.title
ORDER BY new_subscribers DESC;
