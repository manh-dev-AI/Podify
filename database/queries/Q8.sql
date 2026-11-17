-- ===================================================================
-- Query Q8: Tính doanh thu quảng cáo tích lũy theo Creator qua từng tháng
-- Owner: Member 3 - Quang
-- DBMS: MySQL 8.0
-- SQL Concepts: CTE, Aggregation (SUM), Window Function (SUM OVER PARTITION BY ORDER BY)
-- ===================================================================

USE podify_db;

WITH MonthlyCreatorRevenue AS (
    SELECT
        cr.creator_id,
        cr.display_name AS creator_name,
        DATE_FORMAT(ar.revenue_date, '%Y-%m') AS revenue_month,
        SUM(ar.impressions) AS monthly_impressions,
        SUM(ar.amount) AS monthly_revenue
    FROM AdRevenue ar
    INNER JOIN AdContracts ac ON ar.contract_id = ac.contract_id
    INNER JOIN Creators cr ON ac.creator_id = cr.creator_id
    GROUP BY cr.creator_id, cr.display_name, DATE_FORMAT(ar.revenue_date, '%Y-%m')
)
SELECT
    creator_id,
    creator_name,
    revenue_month,
    monthly_impressions,
    monthly_revenue,
    SUM(monthly_revenue) OVER (
        PARTITION BY creator_id
        ORDER BY revenue_month ASC
        ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    ) AS cumulative_revenue
FROM MonthlyCreatorRevenue
ORDER BY creator_id ASC, revenue_month ASC;
