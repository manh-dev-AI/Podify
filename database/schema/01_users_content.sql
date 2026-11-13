-- ===================================================================
-- Module 01: Content Management (Core Content Module)
-- Owner: Member 1 - Mạnh (Schema Owner)
-- DBMS: Microsoft SQL Server (T-SQL)
-- Tables: Users, Creators, PodcastChannels, Episodes
-- ===================================================================

USE podify_db;
GO

-- 1. Bảng Users: Quản lý tài khoản người dùng
IF OBJECT_ID('dbo.Episodes', 'U') IS NOT NULL DROP TABLE dbo.Episodes;
IF OBJECT_ID('dbo.PodcastChannels', 'U') IS NOT NULL DROP TABLE dbo.PodcastChannels;
IF OBJECT_ID('dbo.Creators', 'U') IS NOT NULL DROP TABLE dbo.Creators;
IF OBJECT_ID('dbo.Users', 'U') IS NOT NULL DROP TABLE dbo.Users;
GO

CREATE TABLE dbo.Users (
    user_id INT IDENTITY(1,1) PRIMARY KEY,
    username VARCHAR(50) NOT NULL UNIQUE,
    email VARCHAR(100) NOT NULL UNIQUE,
    password_hash VARCHAR(255) NOT NULL,
    full_name NVARCHAR(100) NOT NULL,
    role VARCHAR(20) NOT NULL DEFAULT 'user' CHECK (role IN ('user', 'creator', 'admin')),
    avatar_url VARCHAR(255) NULL,
    created_at DATETIME2 NOT NULL DEFAULT GETDATE(),
    updated_at DATETIME2 NOT NULL DEFAULT GETDATE()
);
GO

-- 2. Bảng Creators: Hồ sơ người sáng tạo nội dung (Quan hệ 1:0..1 với Users)
CREATE TABLE dbo.Creators (
    creator_id INT IDENTITY(1,1) PRIMARY KEY,
    user_id INT NOT NULL UNIQUE, -- Đảm bảo 1 user chỉ có duy nhất 1 hồ sơ Creator
    display_name NVARCHAR(100) NOT NULL,
    bio NVARCHAR(500) NULL,
    verified BIT NOT NULL DEFAULT 0, -- 0: Chưa xác minh, 1: Đã xác minh
    created_at DATETIME2 NOT NULL DEFAULT GETDATE(),
    CONSTRAINT FK_Creators_Users FOREIGN KEY (user_id) 
        REFERENCES dbo.Users(user_id) ON DELETE CASCADE
);
GO

-- 3. Bảng PodcastChannels: Kênh Podcast do Creator quản lý (Quan hệ 1:N với Creators)
CREATE TABLE dbo.PodcastChannels (
    channel_id INT IDENTITY(1,1) PRIMARY KEY,
    creator_id INT NOT NULL,
    title NVARCHAR(200) NOT NULL,
    description NVARCHAR(MAX) NULL,
    category NVARCHAR(50) NOT NULL, -- vd: Công nghệ, Kể chuyện, Giáo dục, Tin tức
    cover_image_url VARCHAR(255) NULL,
    created_at DATETIME2 NOT NULL DEFAULT GETDATE(),
    updated_at DATETIME2 NOT NULL DEFAULT GETDATE(),
    CONSTRAINT FK_Channels_Creators FOREIGN KEY (creator_id) 
        REFERENCES dbo.Creators(creator_id) ON DELETE CASCADE
);
GO

-- 4. Bảng Episodes: Các tập Podcast thuộc Channel (Quan hệ 1:N với PodcastChannels)
CREATE TABLE dbo.Episodes (
    episode_id INT IDENTITY(1,1) PRIMARY KEY,
    channel_id INT NOT NULL,
    title NVARCHAR(255) NOT NULL,
    description NVARCHAR(MAX) NULL,
    audio_url VARCHAR(255) NOT NULL,
    duration_seconds INT NOT NULL CHECK (duration_seconds > 0), -- Đơn vị: GIÂY (900s = 15p, 1800s = 30p)
    published_at DATETIME2 NULL,
    status VARCHAR(20) NOT NULL DEFAULT 'draft' CHECK (status IN ('draft', 'published', 'archived')),
    created_at DATETIME2 NOT NULL DEFAULT GETDATE(),
    CONSTRAINT FK_Episodes_Channels FOREIGN KEY (channel_id) 
        REFERENCES dbo.PodcastChannels(channel_id) ON DELETE CASCADE
);
GO
