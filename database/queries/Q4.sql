-- ===================================================================
-- Query Q4: Tìm các Channel có Rating trung bình dưới 3
-- Owner: Member 2 - Quân
-- DBMS: MySQL 8.0
-- SQL Concepts: Multi-table INNER JOIN, Aggregate AVG/COUNT, GROUP BY, HAVING
-- ===================================================================

USE podify_db;

SELECT
    c.channel_id,
    c.title AS channel_title,
    cr.display_name AS creator_name,
    COUNT(r.rating_id) AS total_ratings,
    ROUND(AVG(r.score), 2) AS avg_rating
FROM PodcastChannels c
INNER JOIN Creators cr ON c.creator_id = cr.creator_id
INNER JOIN Episodes e ON c.channel_id = e.channel_id
INNER JOIN Ratings r ON e.episode_id = r.episode_id
GROUP BY c.channel_id, c.title, cr.display_name
HAVING AVG(r.score) < 3.0
ORDER BY avg_rating ASC;
