-- ===================================================================
-- Query Q1: Tìm Episodes có thời lượng từ 15–30 phút thuộc Channel cụ thể
-- Owner: Member 1 - Mạnh
-- DBMS: MySQL
-- SQL Concepts: SELECT, INNER JOIN, WHERE, BETWEEN
-- ===================================================================

USE podify_db;

SET @target_channel_id = 1; -- Channel cần tìm kiếm (ví dụ Channel 1)

SELECT 
    e.episode_id,
    c.title AS channel_name,
    e.title AS episode_title,
    e.duration_seconds,
    SEC_TO_TIME(e.duration_seconds) AS duration_formatted, -- Chuyển giây sang định dạng HH:MM:SS
    e.published_at,
    e.status
FROM Episodes e
INNER JOIN PodcastChannels c ON e.channel_id = c.channel_id
WHERE e.channel_id = @target_channel_id
  AND e.status = 'published'
  AND e.duration_seconds BETWEEN 900 AND 1800 -- 15 phút (900s) đến 30 phút (1800s)
ORDER BY e.duration_seconds ASC;
