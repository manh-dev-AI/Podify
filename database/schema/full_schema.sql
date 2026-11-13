-- Podify Official Shared Database Schema (Microsoft SQL Server / T-SQL - 12 Tables)
-- Managed by Schema Owner: Mạnh
-- Order of Execution: 01_users_content.sql -> 02_listening.sql -> 03_advertisement.sql

IF NOT EXISTS (SELECT * FROM sys.databases WHERE name = 'podify_db')
BEGIN
    CREATE DATABASE podify_db;
END
GO

USE podify_db;
GO
