-- ===================================================================
-- Query Q5: Danh sách Episode và số lượt nghe (kể cả Episode chưa có lượt nghe)
-- Owner: Member 2 - Quân
-- DBMS: MySQL 8.0
-- SQL Concepts: LEFT JOIN, COUNT(column) không đếm NULL, GROUP BY
-- ===================================================================

USE podify_db;

SELECT e.episode_id, e.title,
       COUNT(lh.history_id) AS listen_count
FROM Episodes e
LEFT OUTER JOIN ListeningHistory lh
    ON e.episode_id = lh.episode_id
WHERE e.channel_id = 1
GROUP BY e.episode_id, e.title
ORDER BY listen_count DESC;
