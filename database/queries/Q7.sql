-- ===================================================================
-- Query Q7: Tìm Users có tài khoản trên 6 tháng nhưng chưa từng Subscribe
-- Owner: Member 1 - Mạnh
-- DBMS: Microsoft SQL Server (T-SQL)
-- SQL Concepts: Subquery (NOT EXISTS), Date Functions (DATEDIFF, DATEADD)
-- ===================================================================

USE podify_db;
GO

SELECT 
    u.user_id,
    u.username,
    u.full_name,
    u.email,
    u.created_at,
    DATEDIFF(DAY, u.created_at, GETDATE()) AS days_since_registered
FROM dbo.Users u
WHERE u.created_at < DATEADD(MONTH, -6, GETDATE()) -- Tài khoản tạo hơn 6 tháng
  AND NOT EXISTS (
      -- Kiểm tra xem user này đã từng xuất hiện trong bảng Subscriptions của Quân hay chưa
      SELECT 1 
      FROM dbo.Subscriptions s 
      WHERE s.user_id = u.user_id
  )
ORDER BY u.created_at ASC;
GO
