-- ===================================================================
-- Query Q5: Danh sách Episode và số lượt nghe (kể cả Episode chưa có lượt nghe)
-- Owner: Member 2 - Quân
-- DBMS: MySQL 8.0
-- SQL Concepts: LEFT JOIN, COUNT(column) không đếm NULL, GROUP BY
-- ===================================================================

USE podify_db;

SELECT
    e.episode_id,
    c.title AS channel_title,
    e.title AS episode_title,
    e.duration_seconds,
    SEC_TO_TIME(e.duration_seconds) AS duration_formatted,
    e.status,
    COUNT(lh.history_id) AS listen_count
FROM Episodes e
INNER JOIN PodcastChannels c ON e.channel_id = c.channel_id
LEFT JOIN ListeningHistory lh ON e.episode_id = lh.episode_id
GROUP BY e.episode_id, c.title, e.title, e.duration_seconds, e.status
ORDER BY listen_count DESC, e.episode_id ASC;
