-- ===================================================================
-- Module 01: Content Management (Core Content Module)
-- Owner: Member 1 - Mạnh (Schema Owner)
-- DBMS: MySQL
-- Tables: Users, Creators, PodcastChannels, Episodes
-- ===================================================================

USE podify_db;

-- 1. Bảng Users: Quản lý tài khoản người dùng
DROP TABLE IF EXISTS Episodes;
DROP TABLE IF EXISTS PodcastChannels;
DROP TABLE IF EXISTS Creators;
DROP TABLE IF EXISTS Users;

CREATE TABLE Users (
    user_id INT AUTO_INCREMENT PRIMARY KEY,
    username VARCHAR(50) NOT NULL UNIQUE,
    email VARCHAR(100) NOT NULL UNIQUE,
    password_hash VARCHAR(255) NOT NULL,
    full_name VARCHAR(100) NOT NULL,
    role ENUM('user', 'creator', 'admin') NOT NULL DEFAULT 'user',
    avatar_url VARCHAR(255) NULL,
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 2. Bảng Creators: Hồ sơ người sáng tạo nội dung (Quan hệ 1:0..1 với Users)
CREATE TABLE Creators (
    creator_id INT AUTO_INCREMENT PRIMARY KEY,
    user_id INT NOT NULL UNIQUE, -- Đảm bảo 1 user chỉ có duy nhất 1 hồ sơ Creator
    display_name VARCHAR(100) NOT NULL,
    bio TEXT NULL,
    verified BOOLEAN NOT NULL DEFAULT FALSE,
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT FK_Creators_Users FOREIGN KEY (user_id) 
        REFERENCES Users(user_id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 3. Bảng PodcastChannels: Kênh Podcast do Creator quản lý (Quan hệ 1:N với Creators)
CREATE TABLE PodcastChannels (
    channel_id INT AUTO_INCREMENT PRIMARY KEY,
    creator_id INT NOT NULL,
    title VARCHAR(200) NOT NULL,
    description TEXT NULL,
    category VARCHAR(50) NOT NULL,
    cover_image_url VARCHAR(255) NULL,
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    CONSTRAINT FK_Channels_Creators FOREIGN KEY (creator_id) 
        REFERENCES Creators(creator_id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 4. Bảng Episodes: Các tập Podcast thuộc Channel (Quan hệ 1:N với PodcastChannels)
CREATE TABLE Episodes (
    episode_id INT AUTO_INCREMENT PRIMARY KEY,
    channel_id INT NOT NULL,
    title VARCHAR(255) NOT NULL,
    description TEXT NULL,
    audio_url VARCHAR(255) NOT NULL,
    duration_seconds INT NOT NULL, -- Đơn vị: GIÂY (900s = 15p, 1800s = 30p)
    published_at DATETIME NULL,
    status ENUM('draft', 'published', 'archived') NOT NULL DEFAULT 'draft',
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT CHK_Episodes_Duration CHECK (duration_seconds > 0),
    CONSTRAINT FK_Episodes_Channels FOREIGN KEY (channel_id) 
        REFERENCES PodcastChannels(channel_id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
