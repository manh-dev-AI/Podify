-- ===================================================================
-- Query Q6: Tìm các tập podcast có số lượt nghe vượt trội so với số lượt nghe trung bình của các tập khác trong cùng kênh đó.
-- Owner: Member 2 - Quân
-- DBMS: MySQL 8.0
-- SQL Concepts: CTE (WITH), LEFT JOIN, GROUP BY, AVG, Correlated Subquery
-- ===================================================================

USE podify_db;

-- Đếm số lượt nghe của từng Episode
WITH EpisodeListens AS (
    SELECT e.episode_id, e.channel_id, e.title,
           COUNT(lh.history_id) AS listen_count
    FROM Episodes e
    LEFT JOIN ListeningHistory lh
        ON e.episode_id = lh.episode_id
    GROUP BY e.episode_id, e.channel_id, e.title
)
-- Sử dụng truy vấn con tương quan để tính trung bình
-- lượt nghe của các Episode khác trong cùng Channel
SELECT el.episode_id, el.channel_id,
       el.title, el.listen_count
FROM EpisodeListens el
WHERE el.listen_count > (
    SELECT AVG(ep.listen_count)
    FROM EpisodeListens ep
    WHERE ep.channel_id = el.channel_id
      AND ep.episode_id <> el.episode_id
)
ORDER BY el.channel_id ASC, el.listen_count DESC;