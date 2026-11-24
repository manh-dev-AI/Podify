-- ===================================================================
-- Query Q4: Tìm các Channel có Rating trung bình dưới 3
-- Owner: Member 2 - Quân
-- DBMS: MySQL 8.0
-- SQL Concepts: Multi-table INNER JOIN, Aggregate AVG/COUNT, GROUP BY, HAVING
-- ===================================================================

USE podify_db;

SELECT
    c.channel_id,
    c.title,
    ROUND(AVG(r.score), 2) AS avg_rating
FROM Ratings r
INNER JOIN Episodes e ON r.episode_id = e.episode_id
INNER JOIN PodcastChannels c ON e.channel_id = c.channel_id
GROUP BY c.channel_id, c.title
HAVING AVG(r.score) < 3
ORDER BY avg_rating ASC;