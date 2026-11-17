-- ===================================================================
-- Query Q6: Tìm các Episodes có lượt nghe cao hơn trung bình các Episodes khác cùng Channel
-- Owner: Member 2 - Quân
-- DBMS: MySQL 8.0
-- SQL Concepts: CTE (WITH), LEFT JOIN, Window Functions (SUM/COUNT OVER PARTITION BY)
-- ===================================================================

USE podify_db;

WITH EpisodeListens AS (
    SELECT
        e.episode_id,
        e.channel_id,
        c.title AS channel_title,
        e.title AS episode_title,
        COUNT(lh.history_id) AS listen_count
    FROM Episodes e
    INNER JOIN PodcastChannels c ON e.channel_id = c.channel_id
    LEFT JOIN ListeningHistory lh ON e.episode_id = lh.episode_id
    GROUP BY e.episode_id, e.channel_id, c.title, e.title
),
ChannelPeerAverage AS (
    SELECT
        episode_id,
        channel_id,
        channel_title,
        episode_title,
        listen_count,
        -- Trung bình của CÁC EPISODE KHÁC trong cùng Channel: (Tổng kênh - tập hiện tại) / (Số tập kênh - 1)
        ROUND(
            (SUM(listen_count) OVER (PARTITION BY channel_id) - listen_count)
            / NULLIF(COUNT(*) OVER (PARTITION BY channel_id) - 1, 0),
            2
        ) AS avg_other_episodes_listens
    FROM EpisodeListens
)
SELECT
    episode_id,
    channel_id,
    channel_title,
    episode_title,
    listen_count,
    avg_other_episodes_listens
FROM ChannelPeerAverage
WHERE avg_other_episodes_listens IS NOT NULL
  AND listen_count > avg_other_episodes_listens
ORDER BY channel_id ASC, listen_count DESC;
