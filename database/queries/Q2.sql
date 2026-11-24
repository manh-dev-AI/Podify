-- ===================================================================
-- Query Q2: Hiển thị danh sách các quảng cáo được phát trong tập podcast EP99.
-- Owner: Member 3 - Quang
-- DBMS: MySQL 8.0
-- SQL Concepts: Multi-table INNER JOIN (4 bảng), LIKE filter, ORDER BY
-- ===================================================================

USE podify_db;

SELECT e.episode_id,
       e.title AS episode_title,
       a.ad_id,
       a.title AS ad_title,
       a.advertiser_name,
       a.duration_seconds,
       s.start_offset_seconds
FROM Episodes e
INNER JOIN AdSlots s ON e.episode_id = s.episode_id
INNER JOIN AdContracts ac ON s.contract_id = ac.contract_id
INNER JOIN Advertisements a ON ac.ad_id = a.ad_id
WHERE e.title = 'EP99' OR e.title LIKE 'EP99 - %'
ORDER BY s.start_offset_seconds ASC;
