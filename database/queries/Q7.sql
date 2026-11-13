-- ===================================================================
-- Query Q7: Tìm Users có tài khoản trên 6 tháng nhưng chưa từng Subscribe
-- Owner: Member 1 - Mạnh
-- DBMS: MySQL
-- SQL Concepts: Subquery (NOT EXISTS), Date Functions (TIMESTAMPDIFF, DATE_SUB)
-- ===================================================================

USE podify_db;

SELECT 
    u.user_id,
    u.username,
    u.full_name,
    u.email,
    u.created_at,
    TIMESTAMPDIFF(DAY, u.created_at, NOW()) AS days_since_registered
FROM Users u
WHERE u.created_at < DATE_SUB(NOW(), INTERVAL 6 MONTH) -- Tài khoản tạo hơn 6 tháng
  AND NOT EXISTS (
      -- Kiểm tra xem user này đã từng xuất hiện trong bảng Subscriptions của Quân hay chưa
      SELECT 1 
      FROM Subscriptions s 
      WHERE s.user_id = u.user_id
  )
ORDER BY u.created_at ASC;
