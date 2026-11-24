-- ===================================================================
-- Query Q8: Window Functions: Sử dụng SUM() OVER(PARTITION BY ... ORDER BY ...) để tính doanh thu tích lũy tiền quảng cáo của Creator theo từng tháng trong năm.
-- Owner: Member 3 - Quang
-- DBMS: MySQL 8.0
-- SQL Concepts: CTE, Aggregation (SUM), Window Function (SUM OVER PARTITION BY ORDER BY)
-- ===================================================================

USE podify_db;

WITH MonthlyCreatorRevenue AS (
    SELECT cr.creator_id,
           cr.display_name AS creator_name,
           YEAR(ar.revenue_date) AS revenue_year,
           MONTH(ar.revenue_date) AS revenue_month,
           SUM(ar.amount) AS monthly_revenue
    FROM AdRevenue ar
    INNER JOIN AdContracts ac
        ON ar.contract_id = ac.contract_id
    INNER JOIN Creators cr
        ON ac.creator_id = cr.creator_id
    GROUP BY cr.creator_id, cr.display_name,
             YEAR(ar.revenue_date),
             MONTH(ar.revenue_date)
)
SELECT creator_id, creator_name,
       revenue_year, revenue_month, monthly_revenue,
       SUM(monthly_revenue) OVER (
           PARTITION BY creator_id, revenue_year
           ORDER BY revenue_month ASC
           ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
       ) AS cumulative_revenue
FROM MonthlyCreatorRevenue
ORDER BY creator_id ASC, revenue_year ASC, revenue_month ASC;
