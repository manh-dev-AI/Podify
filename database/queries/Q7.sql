-- ===================================================================
-- Query Q7: Tìm người dùng có tài khoản trên 6 tháng nhưng chưa từng bấm đăng ký bất kỳ kênh Podcast nào.
-- Owner: Member 1 - Mạnh
-- DBMS: MySQL
-- SQL Concepts: Subquery (NOT EXISTS), Date Functions (TIMESTAMPDIFF, DATE_SUB)
-- ===================================================================

USE podify_db;

SELECT u.user_id, u.username, u.full_name,
       u.email, u.created_at
FROM Users u
WHERE u.created_at < DATE_SUB(NOW(), INTERVAL 6 MONTH)
    AND u.user_id NOT IN (
        SELECT s.user_id
        FROM Subscriptions s
    )
ORDER BY u.created_at ASC;
