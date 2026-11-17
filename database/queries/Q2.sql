-- ===================================================================
-- Query Q2: Tìm các quảng cáo xuất hiện trong EP99
-- Owner: Member 3 - Quang
-- DBMS: MySQL 8.0
-- SQL Concepts: Multi-table INNER JOIN (4 bảng), LIKE filter, ORDER BY
-- ===================================================================

USE podify_db;

SELECT
    e.episode_id,
    e.title AS episode_title,
    s.slot_id,
    s.slot_position,
    s.start_offset_seconds,
    SEC_TO_TIME(s.start_offset_seconds) AS offset_formatted,
    ac.contract_code,
    a.ad_id,
    a.advertiser_name,
    a.title AS ad_title,
    a.duration_seconds AS ad_duration_seconds,
    a.target_url
FROM Episodes e
INNER JOIN AdSlots s ON e.episode_id = s.episode_id
INNER JOIN AdContracts ac ON s.contract_id = ac.contract_id
INNER JOIN Advertisements a ON ac.ad_id = a.ad_id
WHERE e.title LIKE 'EP99%'
ORDER BY s.start_offset_seconds ASC;
