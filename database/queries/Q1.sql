-- ===================================================================
-- Query Q1: Tìm các tập podcast có thời lượng từ 15 đến 30 phút của kênh "Tri Thức Vn".
-- Owner: Member 1 - Mạnh
-- DBMS: MySQL
-- SQL Concepts: SELECT, INNER JOIN, WHERE, BETWEEN
-- ===================================================================

USE podify_db;

SELECT e.episode_id, e.title,
       c.title AS channel_name,
       e.duration_seconds
FROM Episodes e
INNER JOIN PodcastChannels c
    ON e.channel_id = c.channel_id
WHERE c.title = 'Tri Thức Vn'
    AND e.duration_seconds BETWEEN 900 AND 1800
ORDER BY e.duration_seconds ASC;
