-- ===================================================================
-- Query Q6: Tìm các Episodes có lượt nghe cao hơn trung bình các Episodes khác cùng Channel
-- Owner: Member 2 - Quân
-- DBMS: MySQL 8.0
-- SQL Concepts: CTE (WITH), LEFT JOIN, Window Functions (SUM/COUNT OVER PARTITION BY)
-- ===================================================================

USE podify_db;

WITH EpisodeListens AS (
    SELECT e.episode_id, e.channel_id, e.title,
           COUNT(lh.history_id) AS listen_count
    FROM Episodes e
    LEFT JOIN ListeningHistory lh
        ON e.episode_id = lh.episode_id
    GROUP BY e.episode_id, e.channel_id, e.title
),
ChannelAverage AS (
    SELECT *,
        (SUM(listen_count) OVER (PARTITION BY channel_id)
         - listen_count)
        / NULLIF(
            COUNT(*) OVER (PARTITION BY channel_id) - 1, 0
        ) AS avg_other
    FROM EpisodeListens
)
SELECT episode_id, channel_id, title,
       listen_count, ROUND(avg_other, 2) AS avg_other
FROM ChannelAverage
WHERE listen_count > avg_other
ORDER BY channel_id ASC, listen_count DESC;